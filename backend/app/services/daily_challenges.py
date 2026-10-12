"""Desafios do dia: o sorteio, a medição e a recompensa de cada um.

O servidor sorteia e mede — o aplicativo só desenha o que vem daqui. Sortear no
aplicativo deixaria o resgate sem autoridade: bastaria inventar um "desafio
concluído" local para cobrar pontos.

O sorteio é determinístico e nada é armazenado: a seed mistura o apelido com o
dia local (`2026-10-12`), então cada competidor recebe um conjunto único e
estável por 24h, recalculado a cada abertura. O terceiro desafio é sempre
personalizado pelo histórico da semana.

A recompensa vem da raridade, e é ela que o card mostra antes do resgate:

- comum: 20 pontos de temporada;
- raro: 40 pontos + 30 dracmas;
- épico: 80 pontos + 60 dracmas.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date, datetime, timedelta

# (pontos de temporada, dracmas) por faixa. Um único lugar para as duas
# telas e para o resgate lerem.
REWARDS: dict[str, tuple[int, int]] = {
    "comum": (20, 0),
    "raro": (40, 30),
    "épico": (80, 60),
}


@dataclass(frozen=True)
class Challenge:
    """Um desafio sorteado, com a recompensa que ele paga."""

    id: str
    title: str
    detail: str
    unit: str
    target: float
    rarity: str
    kind: str

    @property
    def points(self) -> int:
        return REWARDS[self.rarity][0]

    @property
    def coins(self) -> int:
        return REWARDS[self.rarity][1]


# A ordem importa: o sorteio embaralha esta lista, e mudar a ordem muda o
# desafio de todo mundo no mesmo dia.
POOL: tuple[Challenge, ...] = (
    Challenge("run-once", "Sair do lugar", "Complete a primeira corrida do dia", "corridas", 1, "comum", "count"),
    Challenge("km-3", "Três quilômetros", "Curta distância para manter o hábito", "km", 3, "comum", "distance"),
    Challenge("min-20", "Vinte minutos em movimento", "No seu ritmo, sem pressa", "min", 20, "comum", "duration"),
    Challenge("km-5", "Cinco quilômetros", "A distância clássica de treino", "km", 5, "raro", "distance"),
    Challenge("twice", "Dupla do dia", "Duas corridas em um só dia", "corridas", 2, "raro", "count"),
    Challenge("dawn", "Corredor da aurora", "Corra antes das 8h", "corridas", 1, "raro", "dawn"),
    Challenge("night", "Corredor da noite", "Corra depois das 19h", "corridas", 1, "raro", "night"),
    Challenge("min-40", "Quarenta minutos", "Sessão longa de aeróbico", "min", 40, "raro", "duration"),
    Challenge("pace", "Racho afiado", "Ritmo médio abaixo de 6 min/km", "min/km", 6, "épico", "pace"),
    Challenge("km-8", "Oito quilômetros", "Longão de respeito", "km", 8, "épico", "distance"),
)


@dataclass(frozen=True)
class DaySummary:
    """O que as corridas de um dia dizem, no fuso do aparelho."""

    count: int
    distance_km: float
    minutes: float
    start_hours: tuple[int, ...]
    fastest_pace_min_km: float | None


def day_key(local_day: date) -> str:
    return local_day.isoformat()


def local_day(now: datetime, utc_offset_minutes: int) -> date:
    """O dia do competidor, não o de UTC: meia-noite em UTC não é o sorteio."""
    return (now + timedelta(minutes=utc_offset_minutes)).date()


def draw(username: str, local_day_value: date, weekly_km: float, longest_km: float) -> list[Challenge]:
    """Os três desafios do dia: dois do sorteio + um personalizado."""
    seed = _seed_from(f"{username.strip().lower()}|{day_key(local_day_value)}")
    picked = _shuffled(list(POOL), seed)[:2]
    picked.append(personalized(weekly_km=weekly_km, longest_km=longest_km))
    return picked


def personalized(weekly_km: float, longest_km: float) -> Challenge:
    """Desafio único: o alvo acompanha a média diária e o longão da semana."""
    base = max(weekly_km / 7, longest_km / 2)
    target = min(15.0, max(3.0, math.ceil(base + 1.5)))
    return Challenge(
        "personal",
        "Longão pessoal",
        "Um passo além da sua média diária, feito para você",
        "km",
        float(target),
        "épico",
        "distance",
    )


def summarize(
    runs: list[tuple[datetime, float, int]],
    local_day_value: date,
    utc_offset_minutes: int,
) -> DaySummary:
    """Agrupa as corridas salvas do dia. Cada item é (started_at_utc, metros, segundos)."""
    count = 0
    distance_m = 0.0
    seconds = 0.0
    start_hours: list[int] = []
    fastest: float | None = None
    for started_at, distance, duration in runs:
        local = started_at + timedelta(minutes=utc_offset_minutes)
        if local.date() != local_day_value:
            continue
        count += 1
        distance_m += distance or 0
        seconds += duration or 0
        start_hours.append(local.hour)
        # O ritmo só conta de corrida de pelo menos 1 km: `create_run` aceita
        # corridas a partir de 10 m, e um trote de 10 m em 1 s daria 1,7 min/km
        # — o épico "Racho afiado" se completaria sozinho na calçada.
        if distance >= 1000 and duration > 0:
            pace = duration / 60 / (distance / 1000)
            if fastest is None or pace < fastest:
                fastest = pace
    return DaySummary(
        count=count,
        distance_km=distance_m / 1000,
        minutes=seconds / 60,
        start_hours=tuple(start_hours),
        fastest_pace_min_km=fastest,
    )


def measure(challenge: Challenge, summary: DaySummary) -> tuple[float, bool]:
    """(valor atual, concluído) do desafio contra o resumo do dia."""
    if challenge.kind == "count":
        value = float(summary.count)
    elif challenge.kind == "distance":
        value = round(summary.distance_km, 2)
    elif challenge.kind == "duration":
        value = round(summary.minutes)
    elif challenge.kind == "dawn":
        value = float(any(hour < 8 for hour in summary.start_hours))
    elif challenge.kind == "night":
        value = float(any(hour >= 19 for hour in summary.start_hours))
    elif challenge.kind == "pace":
        pace = summary.fastest_pace_min_km
        if pace is None:
            return 0.0, False
        return round(pace, 2), pace < challenge.target
    else:  # pragma: no cover - pool fechado, sem kinds fora da lista
        return 0.0, False
    return value, value >= challenge.target


def _seed_from(text: str) -> int:
    """FNV-1a de 32 bits, a mesma função que o sorteio sempre usou."""
    hash_value = 0x811C9DC5
    for byte in text.encode("utf-8"):
        hash_value ^= byte
        hash_value = (hash_value * 0x01000193) & 0xFFFFFFFF
    return hash_value


def _shuffled(items: list[Challenge], seed: int) -> list[Challenge]:
    """Fisher-Yates com o gerador xorshift determinístico da seed."""
    result = list(items)
    state = seed | 1
    for i in range(len(result) - 1, 0, -1):
        state = _next_state(state)
        j = state % (i + 1)
        result[i], result[j] = result[j], result[i]
    return result


def _next_state(state: int) -> int:
    state ^= (state << 13) & 0xFFFFFFFF
    state &= 0xFFFFFFFF
    state ^= state >> 17
    state ^= (state << 5) & 0xFFFFFFFF
    return state & 0xFFFFFFFF
