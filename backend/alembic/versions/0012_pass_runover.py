"""Pass Runover: trilha premium e resgates por temporada.

Cria pass_premium + pass_claims. Idempotente de propósito: o create_all
continua criando o esquema completo em bancos novos, então a revisão
tolera tabelas já existentes.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0012_pass_runover"
down_revision = "0011_user_accent_color"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    tables = set(inspect(conn).get_table_names())
    if "pass_premium" not in tables:
        op.create_table(
            "pass_premium",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("season_id", sa.String(7), nullable=False, index=True),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("user_id", "season_id", name="uq_pass_premium"),
        )
    if "pass_claims" not in tables:
        op.create_table(
            "pass_claims",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False, index=True),
            sa.Column("season_id", sa.String(7), nullable=False, index=True),
            sa.Column("tier", sa.Integer(), nullable=False),
            sa.Column("track", sa.String(16), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=True),
            sa.UniqueConstraint("user_id", "season_id", "tier", "track", name="uq_pass_claim"),
        )


def downgrade() -> None:
    op.drop_table("pass_claims")
    op.drop_table("pass_premium")
