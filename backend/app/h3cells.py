"""Índice espacial H3 (Uber) — âncora geográfica do jogo.

A posse continua sendo o polígono orgânico do laço (RN05); o H3 entra
como *índice*: a célula do centroide de cada território, guardada como
string indexada, para buscas por proximidade sem varredura. O filtro
exato (haversine no centroide) continua decidindo em Python — a célula
só restringe os candidatos, então trocar o pré-filtro não muda nenhum
resultado. Fases futuras (enter-hex, cerco, blitz) usam estas mesmas
células como âncora.
"""

import math

import h3

# Resolução 9 (~0,1 km² por célula, aresta de ~170 m): granularidade
# urbana — fina o bastante para viewport de mapa, grossa o bastante para
# o disco de cobertura de raios pequenos caber num IN indexado.
H3_RESOLUTION = 9

# Raio equivalente aproximado de uma célula res 9, com margem: a
# cobertura usa ceil(raio / CELL_RADIUS_M) + 1 anéis, garantindo que o
# conjunto de células é sempre um superconjunto do disco consultado.
CELL_RADIUS_M = 250.0

# Teto do conjunto de cobertura: acima disso o chamador recai no
# pré-filtro por caixa delimitadora (mesmos resultados, outro índice).
MAX_COVER_CELLS = 1000


def cell_for(lat: float, lng: float, resolution: int = H3_RESOLUTION) -> str:
    """Célula H3 (string, ex. '89a8100c02fffff') de um ponto."""
    if not (-90.0 <= lat <= 90.0):
        raise ValueError(f"Latitude fora do intervalo: {lat}")
    if not (-180.0 <= lng <= 180.0):
        raise ValueError(f"Longitude fora do intervalo: {lng}")
    return h3.latlng_to_cell(lat, lng, resolution)


def covering_cells(
    lat: float, lng: float, radius_m: float, resolution: int = H3_RESOLUTION
) -> set[str] | None:
    """Células cobrindo o disco (ponto, raio).

    Retorna None quando o disco exigiria mais que MAX_COVER_CELLS —
    raios grandes continuam no pré-filtro por caixa delimitadora.
    """
    if radius_m <= 0:
        raise ValueError(f"Raio precisa ser positivo: {radius_m}")
    center = cell_for(lat, lng, resolution)
    rings = math.ceil(radius_m / CELL_RADIUS_M) + 1
    if 3 * (rings + 1) ** 2 > MAX_COVER_CELLS:
        return None
    return set(h3.grid_disk(center, rings))
