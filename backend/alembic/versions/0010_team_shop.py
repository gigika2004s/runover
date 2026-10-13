"""Loja da equipe: cofre (spent_points), cosméticos equipados e inventário.

Acrescenta `spent_points` + colunas de equipamento em teams e cria
team_items. Idempotente de propósito: o create_all continua criando o
esquema completo em bancos novos, então a revisão tolera tabelas/colunas
já existentes.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0010_team_shop"
down_revision = "0009_game_cosmetics"
branch_labels = None
depends_on = None

TEAM_COLUMNS = (
    ("spent_points", sa.Column("spent_points", sa.Integer(), nullable=False, server_default="0")),
    ("equipped_avatar", sa.Column("equipped_avatar", sa.String(64), nullable=True)),
    ("equipped_frame", sa.Column("equipped_frame", sa.String(64), nullable=True)),
    ("equipped_effect", sa.Column("equipped_effect", sa.String(64), nullable=True)),
    ("equipped_banner", sa.Column("equipped_banner", sa.String(64), nullable=True)),
    ("equipped_name_style", sa.Column("equipped_name_style", sa.String(64), nullable=True)),
)


def upgrade() -> None:
    conn = op.get_bind()
    tables = set(inspect(conn).get_table_names())
    if "teams" in tables:
        existing = {c["name"] for c in inspect(conn).get_columns("teams")}
        for name, column in TEAM_COLUMNS:
            if name not in existing:
                op.add_column("teams", column)
    if "team_items" not in tables:
        op.create_table(
            "team_items",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("team_id", sa.String(), sa.ForeignKey("teams.id"), nullable=False, index=True),
            sa.Column("item_id", sa.String(64), nullable=False, index=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("team_id", "item_id", name="uq_team_item"),
        )


def downgrade() -> None:
    op.drop_table("team_items")
    for name, _ in TEAM_COLUMNS:
        op.drop_column("teams", name)
