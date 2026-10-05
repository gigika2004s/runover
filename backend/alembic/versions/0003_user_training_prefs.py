"""Preferências de treino do usuário.

Acrescenta distance_units/weekly_frequency/training_days/activity_level
à tabela users, com valores padrão para as linhas existentes.

As etapas são idempotentes de propósito: o create_all continua criando
o esquema completo em bancos novos, então esta revisão precisa tolerar
colunas já existentes.
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision = "0003_user_training_prefs"
down_revision = "0002_territory_centroid"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "users" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("users")}
    if "distance_units" not in columns:
        op.add_column(
            "users",
            sa.Column("distance_units", sa.String(2), nullable=False, server_default="km"),
        )
    if "weekly_frequency" not in columns:
        op.add_column("users", sa.Column("weekly_frequency", sa.Integer(), nullable=True))
    if "training_days" not in columns:
        op.add_column(
            "users",
            sa.Column("training_days", sa.String(32), nullable=False, server_default=""),
        )
    if "activity_level" not in columns:
        op.add_column("users", sa.Column("activity_level", sa.String(24), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "activity_level")
    op.drop_column("users", "training_days")
    op.drop_column("users", "weekly_frequency")
    op.drop_column("users", "distance_units")
