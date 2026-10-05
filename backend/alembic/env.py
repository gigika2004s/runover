"""Alembic environment: revisões de esquema do RUNOVER.

A criação de tabelas continua com Base.metadata.create_all (ver
app.core.database.initialize_database); as revisões carregam só as
mudanças que o create_all não aplica em bancos existentes, como colunas
e índices novos.
"""
import sys
from logging.config import fileConfig
from pathlib import Path

from sqlalchemy import engine_from_config, pool

from alembic import context

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

from app.core.config import normalize_database_url, pin_ipv4_hostaddr, settings  # noqa: E402
from app.core.database import Base  # noqa: E402
import app.models  # noqa: E402,F401  (registra as tabelas em Base.metadata)

target_metadata = Base.metadata


def _database_url() -> str:
    return pin_ipv4_hostaddr(
        normalize_database_url(
            config.get_main_option("sqlalchemy.url") or settings.database_url
        )
    )


def run_migrations_offline() -> None:
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    configuration = config.get_section(config.config_ini_section, {})
    configuration["sqlalchemy.url"] = _database_url()
    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
