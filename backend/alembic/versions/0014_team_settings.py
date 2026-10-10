"""Ajustes da equipe: modo de entrada, visibilidade, avisos e convite.

Adiciona `join_mode`, `listed`, `notify_risk`, `notify_requests` e
`invite_token` em teams. Idempotente: tolera colunas já existentes
(bancos novos nunca as criam via create_all fora do metadata).
"""

from alembic import op
from sqlalchemy import inspect

revision = "0014_team_settings"
down_revision = "0013_drop_accent_color"
branch_labels = None
depends_on = None


_COLUMNS = (
    ("join_mode", "String(16)", "approval"),
    ("listed", "Boolean", True),
    ("notify_risk", "Boolean", True),
    ("notify_requests", "Boolean", True),
    ("invite_token", "String(64)", None),
)


def upgrade() -> None:
    import sqlalchemy as sa

    conn = op.get_bind()
    if "teams" not in inspect(conn).get_table_names():
        return
    existing = {c["name"] for c in inspect(conn).get_columns("teams")}
    type_map = {
        "String(16)": sa.String(16),
        "String(64)": sa.String(64),
        "Boolean": sa.Boolean(),
    }
    for name, type_name, default in _COLUMNS:
        if name in existing:
            continue
        nullable = name == "invite_token"
        unique = name == "invite_token"
        op.add_column(
            "teams",
            sa.Column(
                name,
                type_map[type_name],
                nullable=nullable,
                server_default=None if nullable else sa.text(
                    f"'{default}'" if isinstance(default, str) else ("1" if default else "0")
                ),
            ),
        )
        if unique:
            op.create_unique_constraint(f"uq_teams_{name}", "teams", [name])


def downgrade() -> None:
    conn = op.get_bind()
    if "teams" not in inspect(conn).get_table_names():
        return
    existing = {c["name"] for c in inspect(conn).get_columns("teams")}
    if "invite_token" in existing:
        op.drop_constraint("uq_teams_invite_token", "teams", type_="unique")
    for name, _, _ in _COLUMNS:
        if name in existing:
            op.drop_column("teams", name)
