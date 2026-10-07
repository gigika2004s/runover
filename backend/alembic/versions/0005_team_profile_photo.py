"""Foto de perfil da equipe.

Acrescenta photo_url (texto, nulo) a teams. Idempotente de propósito:
o create_all continua criando o esquema completo em bancos novos,
então a revisão tolera a coluna já existente.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0005_team_profile_photo"
down_revision = "0004_h3_cell_index"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "teams" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("teams")}
    if "photo_url" not in columns:
        op.add_column(
            "teams", sa.Column("photo_url", sa.String(), nullable=True)
        )


def downgrade() -> None:
    op.drop_column("teams", "photo_url")
