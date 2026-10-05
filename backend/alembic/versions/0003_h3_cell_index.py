"""Célula H3 do centroide para a busca por proximidade.

Acrescenta h3_cell (string indexada, resolução 9 — ver app/h3cells.py)
e preenche as linhas existentes a partir do centroide (ou do geojson
quando o centro ainda é nulo). O endpoint /territories/nearby filtra
por igualdade de string indexada e mantém o haversine exato em Python,
então nenhum resultado muda — só o pré-filtro fica mais barato.

NOTA DE RENUMERAÇÃO: se a branch de training-prefs (migração
0003_user_training_prefs) entrar na main primeiro, renumerar esta
revisão para 0004 com down_revision = "0003_user_training_prefs".

As etapas são idempotentes de propósito: o create_all continua criando
o esquema completo em bancos novos, então esta revisão precisa tolerar
coluna/índice já existentes.
"""

import json

import h3
from alembic import op
import sqlalchemy as sa
from shapely.geometry import shape
from sqlalchemy import inspect

revision = "0003_h3_cell_index"
down_revision = "0002_territory_centroid"
branch_labels = None
depends_on = None

# Congelado no tempo de propósito: migrações não importam app/h3cells.py
# para não mudar de comportamento se o helper evoluir.
_H3_RESOLUTION = 9


def upgrade() -> None:
    conn = op.get_bind()
    if "territories" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("territories")}
    if "h3_cell" not in columns:
        op.add_column(
            "territories", sa.Column("h3_cell", sa.String(15), nullable=True)
        )
    indexes = {i["name"] for i in inspect(conn).get_indexes("territories")}
    if "ix_territories_h3_cell" not in indexes:
        op.create_index("ix_territories_h3_cell", "territories", ["h3_cell"])
    rows = conn.execute(
        sa.text(
            "SELECT id, geojson, center_lat, center_lng FROM territories "
            "WHERE h3_cell IS NULL"
        )
    ).all()
    for territory_id, geojson_text, center_lat, center_lng in rows:
        if center_lat is None or center_lng is None:
            centroid = shape(json.loads(geojson_text)).centroid
            center_lng, center_lat = centroid.x, centroid.y
        conn.execute(
            sa.text(
                "UPDATE territories SET h3_cell = :cell WHERE id = :territory_id"
            ),
            {
                "cell": h3.latlng_to_cell(
                    center_lat, center_lng, _H3_RESOLUTION
                ),
                "territory_id": territory_id,
            },
        )


def downgrade() -> None:
    op.drop_index("ix_territories_h3_cell", table_name="territories")
    op.drop_column("territories", "h3_cell")
