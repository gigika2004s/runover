"""Sinal de presença (app aberto) para o 'online' da equipe.

Cria presence_pings (uma linha por usuário, atualizada a cada sinal).
Idempotente de propósito: o create_all continua criando o esquema
completo em bancos novos, então a revisão tolera a tabela já existente.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0006_presence_pings"
down_revision = "0005_team_profile_photo"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "presence_pings" not in inspect(conn).get_table_names():
        op.create_table(
            "presence_pings",
            sa.Column("user_id", sa.String(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("user_id"),
        )
        op.create_index(
            "ix_presence_pings_updated_at", "presence_pings", ["updated_at"]
        )


def downgrade() -> None:
    op.drop_index("ix_presence_pings_updated_at", table_name="presence_pings")
    op.drop_table("presence_pings")
