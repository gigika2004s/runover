"""Cor de destaque do perfil (`accent_color`, "#RRGGBB").

Coluna anulável em users; gratuita e visível para todos. Idempotente de
propósito: o create_all continua criando o esquema completo em bancos
novos, então a revisão tolera a coluna já existente.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0011_user_accent_color"
down_revision = "0010_team_shop"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "users" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("users")}
    if "accent_color" not in columns:
        op.add_column("users", sa.Column("accent_color", sa.String(7), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "accent_color")
