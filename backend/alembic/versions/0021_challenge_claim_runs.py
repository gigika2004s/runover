"""Recibo de corrida por resgate de desafio do dia.

O fuso horário chega do aparelho (`utc_offset_minutes`), e a faixa aceita cobre
26 horas: uma corrida perto da meia-noite pode caber no dia D com um fuso e no
dia D+1 com outro, pagando duas vezes. A regra do servidor passa a ser uma
corrida pagar um único dia, então o resgate grava quais corridas o mediram.

Idempotente como as anteriores: o `create_all` já monta o esquema completo em
bancos novos, então a revisão tolera a coluna já existente.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0021_challenge_claim_runs"
down_revision = "0020_daily_challenges"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    tables = set(inspect(conn).get_table_names())
    if "daily_challenge_claims" not in tables:
        return
    columns = {c["name"] for c in inspect(conn).get_columns("daily_challenge_claims")}
    if "run_ids" not in columns:
        op.add_column(
            "daily_challenge_claims",
            sa.Column(
                "run_ids",
                sa.Text(),
                nullable=False,
                server_default=sa.text("'[]'"),
            ),
        )


def downgrade() -> None:
    op.drop_column("daily_challenge_claims", "run_ids")
