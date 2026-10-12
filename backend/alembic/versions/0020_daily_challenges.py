"""Resgate de desafio do dia: a tabela que marca o que já foi pago.

O sorteio não é armazenado em lugar nenhum — ele sai do apelido e do dia. O que
precisa existir é o recibo do resgate, para o mesmo desafio não pagar pontos
duas vezes antes da meia-noite local do competidor.

Idempotente como as anteriores: o `create_all` já monta o esquema completo em
bancos novos, então a revisão tolera a tabela já existente.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0020_daily_challenges"
down_revision = "0019_email_verification"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    tables = set(inspect(conn).get_table_names())
    if "users" not in tables:
        return
    if "daily_challenge_claims" not in tables:
        op.create_table(
            "daily_challenge_claims",
            sa.Column("id", sa.String(), nullable=False),
            sa.Column("user_id", sa.String(), nullable=False),
            sa.Column("day", sa.String(length=10), nullable=False),
            sa.Column("challenge_id", sa.String(length=32), nullable=False),
            sa.Column("points", sa.Integer(), nullable=False),
            sa.Column("coins", sa.Integer(), nullable=False),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("user_id", "day", "challenge_id", name="uq_daily_challenge_claim"),
        )
        op.create_index(
            "ix_daily_challenge_claims_user_id",
            "daily_challenge_claims",
            ["user_id"],
        )


def downgrade() -> None:
    op.drop_index("ix_daily_challenge_claims_user_id", table_name="daily_challenge_claims")
    op.drop_table("daily_challenge_claims")
