"""Mercado interno: moedas, inventário e cosméticos.

Acrescenta saldo/colunas de equipamento em users e cria
coin_transactions + user_items. Idempotente de propósito: o create_all
continua criando o esquema completo em bancos novos, então a revisão
tolera tabelas/colunas já existentes.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0006_shop_coins"
down_revision = "0005_team_profile_photo"
branch_labels = None
depends_on = None

USER_COLUMNS = (
    ("coins_balance", sa.Column("coins_balance", sa.Integer(), nullable=False, server_default="0")),
    ("equipped_avatar", sa.Column("equipped_avatar", sa.String(64), nullable=True)),
    ("equipped_frame", sa.Column("equipped_frame", sa.String(64), nullable=True)),
    ("equipped_effect", sa.Column("equipped_effect", sa.String(64), nullable=True)),
    ("equipped_banner", sa.Column("equipped_banner", sa.String(64), nullable=True)),
    ("equipped_name_style", sa.Column("equipped_name_style", sa.String(64), nullable=True)),
    ("equipped_emoticons", sa.Column("equipped_emoticons", sa.String(256), nullable=False, server_default="")),
    ("mural_widgets", sa.Column("mural_widgets", sa.String(256), nullable=False, server_default="emoticons,conquistas,atividades,estatisticas")),
)


def upgrade() -> None:
    conn = op.get_bind()
    tables = set(inspect(conn).get_table_names())
    if "users" in tables:
        existing = {c["name"] for c in inspect(conn).get_columns("users")}
        for name, column in USER_COLUMNS:
            if name not in existing:
                op.add_column("users", column)
    if "coin_transactions" not in tables:
        op.create_table(
            "coin_transactions",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("delta", sa.Integer(), nullable=False),
            sa.Column("reason", sa.String(64), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=True, index=True),
        )
    if "user_items" not in tables:
        op.create_table(
            "user_items",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("item_id", sa.String(64), nullable=False, index=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("user_id", "item_id", name="uq_user_item"),
        )


def downgrade() -> None:
    op.drop_table("user_items")
    op.drop_table("coin_transactions")
    for name, _ in USER_COLUMNS:
        op.drop_column("users", name)
