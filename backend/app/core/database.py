from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import normalize_database_url, settings

# `check_same_thread` só existe no SQLite (dev local). Na nuvem usamos Postgres
# via DATABASE_URL, onde esse arg quebra a conexão.
_url = normalize_database_url(settings.database_url)

if _url.startswith("sqlite"):
    _engine_kwargs = {"connect_args": {"check_same_thread": False}}
else:
    # Render/hosts derrubam conexões ociosas; pre_ping evita "server closed the
    # connection unexpectedly" depois do serviço hibernar.
    _engine_kwargs = {"pool_pre_ping": True}

engine = create_engine(_url, **_engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def initialize_database():
    # Additive migration: existing tables and history remain untouched.
    from app.models import MutationLock
    from sqlalchemy.dialects.sqlite import insert as sqlite_insert
    from sqlalchemy.dialects.postgresql import insert as pg_insert
    Base.metadata.create_all(bind=engine)
    insert = sqlite_insert if engine.dialect.name == "sqlite" else pg_insert
    with engine.begin() as conn:
        conn.execute(insert(MutationLock).values(id=1, version=0).on_conflict_do_nothing())
    _apply_migrations()


def _apply_migrations():
    """ALTERs que o create_all não aplica em bancos existentes (colunas, índices)."""
    from alembic import command
    from alembic.config import Config
    cfg = Config()
    cfg.set_main_option(
        "script_location", str(Path(__file__).resolve().parents[2] / "alembic")
    )
    cfg.set_main_option("sqlalchemy.url", str(engine.url))
    command.upgrade(cfg, "head")


def lock_mutations(db):
    from sqlalchemy import update
    from app.models import MutationLock
    db.execute(update(MutationLock).where(MutationLock.id == 1).values(version=MutationLock.version + 1))
