"""Desativação temporária de conta.

Acrescenta is_active/deactivated_at a users. Idempotente de propósito:
o create_all continua criando o esquema completo em bancos novos,
então a revisão tolera colunas já existentes.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0007_account_deactivation"
down_revision = "0006_shop_coins"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "users" not in inspect(conn).get_table_names():
        return
    existing = {c["name"] for c in inspect(conn).get_columns("users")}
    if "is_active" not in existing:
        op.add_column(
            "users",
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        )
    if "deactivated_at" not in existing:
        op.add_column("users", sa.Column("deactivated_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "deactivated_at")
    op.drop_column("users", "is_active")
