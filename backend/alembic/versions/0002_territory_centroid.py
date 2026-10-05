"""Centroide indexado para a busca por proximidade.

Acrescenta center_lat/center_lng (com índice) e preenche as linhas
existentes a partir do geojson. O endpoint /territories/nearby filtra
pela caixa ao redor do ponto no SQL e só calcula o haversine exato nos
candidatos — funciona em SQLite e PostgreSQL, sem extensão espacial.

As etapas são idempotentes de propósito: o create_all continua criando
o esquema completo em bancos novos, então esta revisão precisa tolerar
colunas/índices já existentes.
"""

import json

from alembic import op
import sqlalchemy as sa
from shapely.geometry import shape
from sqlalchemy import inspect

revision = "0002_territory_centroid"
down_revision = "0001_baseline"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "territories" not in inspect(conn).get_table_names():
        return
    columns = {c["name"] for c in inspect(conn).get_columns("territories")}
    if "center_lat" not in columns:
        op.add_column("territories", sa.Column("center_lat", sa.Float(), nullable=True))
    if "center_lng" not in columns:
        op.add_column("territories", sa.Column("center_lng", sa.Float(), nullable=True))
    indexes = {i["name"] for i in inspect(conn).get_indexes("territories")}
    if "ix_territories_center_lat" not in indexes:
        op.create_index("ix_territories_center_lat", "territories", ["center_lat"])
    if "ix_territories_center_lng" not in indexes:
        op.create_index("ix_territories_center_lng", "territories", ["center_lng"])
    rows = conn.execute(
        sa.text(
            "SELECT id, geojson FROM territories "
            "WHERE center_lat IS NULL OR center_lng IS NULL"
        )
    ).all()
    for territory_id, geojson_text in rows:
        centroid = shape(json.loads(geojson_text)).centroid
        conn.execute(
            sa.text(
                "UPDATE territories SET center_lat = :lat, center_lng = :lng "
                "WHERE id = :territory_id"
            ),
            {"lat": centroid.y, "lng": centroid.x, "territory_id": territory_id},
        )


def downgrade() -> None:
    op.drop_index("ix_territories_center_lng", table_name="territories")
    op.drop_index("ix_territories_center_lat", table_name="territories")
    op.drop_column("territories", "center_lng")
    op.drop_column("territories", "center_lat")
