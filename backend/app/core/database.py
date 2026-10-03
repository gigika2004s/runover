from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

# `check_same_thread` só existe no SQLite (dev local). Na nuvem usamos Postgres
# via DATABASE_URL, onde esse arg quebra a conexão.
_url = settings.database_url

# Render/Heroku entregam a URL como "postgres://...". O SQLAlchemy 2.x precisa
# de "postgresql+psycopg://" para usar o driver psycopg 3 que instalamos.
if _url.startswith("postgres://"):
    _url = "postgresql+psycopg://" + _url[len("postgres://"):]
elif _url.startswith("postgresql://"):
    _url = "postgresql+psycopg://" + _url[len("postgresql://"):]

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


def lock_mutations(db):
    from sqlalchemy import update
    from app.models import MutationLock
    db.execute(update(MutationLock).where(MutationLock.id == 1).values(version=MutationLock.version + 1))
