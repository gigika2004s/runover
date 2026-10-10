"""Remove a cor de destaque gratuita: cosméticos passam só pela loja.

Derruba a coluna `accent_color` de users. Idempotente: tolera a coluna
já ausente (bancos novos nunca a criam via create_all).
"""

from alembic import op
from sqlalchemy import inspect

revision = "0013_drop_accent_color"
down_revision = "0012_pass_runover"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "users" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("users")}
    if "accent_color" in columns:
        op.drop_column("users", "accent_color")


def downgrade() -> None:
    import sqlalchemy as sa

    op.add_column("users", sa.Column("accent_color", sa.String(7), nullable=True))
