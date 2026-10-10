"""Convite de equipe: quem chamou o jogador (`invited_by`).

Adiciona a coluna em `team_join_requests`. Pedido convidado tem dono: quem
decide é o convidado, não o admin. Idempotente de propósito: o `create_all`
continua criando o esquema completo em bancos novos, então a revisão tolera a
coluna já existente.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0014_team_invites"
down_revision = "0013_user_badges"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "team_join_requests" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("team_join_requests")}
    if "invited_by" not in columns:
        op.add_column(
            "team_join_requests",
            sa.Column("invited_by", sa.String(), sa.ForeignKey("users.id"), nullable=True),
        )
        op.create_index(
            "ix_team_join_requests_invited_by",
            "team_join_requests",
            ["invited_by"],
        )


def downgrade() -> None:
    op.drop_index("ix_team_join_requests_invited_by", table_name="team_join_requests")
    op.drop_column("team_join_requests", "invited_by")
