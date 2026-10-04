"""Importação de corridas do Nike Run Club.

Adaptado do nrc-exporter (https://github.com/yasoob/nrc-exporter),
MIT License, Copyright (c) 2020 Yasoob Khalid — atribuição mantida
conforme os termos da licença. Reimplementado para o RUNOVER com
httpx e o formato de track do aplicativo."""
from datetime import datetime, timezone
from uuid import NAMESPACE_URL, UUID, uuid5

import httpx

ACTIVITY_LIST_URL = (
    "https://api.nike.com/plus/v3/activities/before_id/v3/*"
    "?limit=30&types=run%2Cjogging&include_deleted=false"
)
ACTIVITY_LIST_PAGINATION = (
    "https://api.nike.com/plus/v3/activities/before_id/v3/{before_id}"
    "?limit=30&types=run%2Cjogging&include_deleted=false"
)
ACTIVITY_DETAILS_URL = (
    "https://api.nike.com/sport/v3/me/activity/{activity_id}?metrics=ALL"
)


class NikeApiError(RuntimeError):
    """Falha ao acessar a API da Nike (token inválido, rede, etc.)."""


def _get(url: str, token: str) -> dict:
    try:
        response = httpx.get(
            url, headers={"Authorization": f"Bearer {token}"}, timeout=30.0
        )
    except httpx.HTTPError as exc:
        raise NikeApiError(f"Erro de rede ao acessar a Nike: {exc}") from exc
    if response.status_code != 200:
        raise NikeApiError(f"A Nike respondeu com status {response.status_code}.")
    payload = response.json()
    if "error_id" in payload:
        raise NikeApiError("Token de acesso do Nike Run Club inválido ou expirado.")
    return payload


def fetch_activities(token: str) -> list[str]:
    """Ids das atividades de corrida, em paginação; ignora corridas manuais."""
    activity_ids: list[str] = []
    next_page = ACTIVITY_LIST_URL
    while next_page:
        payload = _get(next_page, token)
        for activity in payload.get("activities", []):
            if activity.get("type") != "run":
                continue
            if activity.get("tags", {}).get("com.nike.running.runtype") == "manual":
                continue
            activity_ids.append(activity["id"])
        next_page = None
        before_id = payload.get("paging", {}).get("before_id")
        if before_id:
            next_page = ACTIVITY_LIST_PAGINATION.format(before_id=before_id)
    return activity_ids


def fetch_activity_details(token: str, activity_id: str) -> dict:
    return _get(ACTIVITY_DETAILS_URL.format(activity_id=activity_id), token)


def activity_to_track(activity: dict) -> list[dict] | None:
    """Converte os métricos de uma atividade NRC em pontos do track do RUNOVER.

    Retorna None quando a atividade não tem dados de GPS.
    """
    latitude: list[dict] | None = None
    longitude: list[dict] | None = None
    for metric in activity.get("metrics") or []:
        if metric.get("type") == "latitude":
            latitude = metric.get("values") or []
        elif metric.get("type") == "longitude":
            longitude = metric.get("values") or []
    if not latitude or not longitude:
        return None
    track: list[dict] = []
    for lat, lon in zip(latitude, longitude):
        if lat.get("start_epoch_ms") != lon.get("start_epoch_ms"):
            continue
        track.append({
            "lat": lat["value"],
            "lng": lon["value"],
            "timestamp": datetime.fromtimestamp(
                lat["start_epoch_ms"] / 1000, tz=timezone.utc
            ).isoformat(),
            "segment": 0,
        })
    return track or None


def activity_to_run_payload(activity: dict) -> dict | None:
    """Atividade NRC -> payload aceito por POST /runs (RunRequest)."""
    track = activity_to_track(activity)
    if not track or len(track) < 2:
        return None
    raw_id = str(activity.get("id") or "")
    try:
        run_id = UUID(raw_id)
    except ValueError:
        run_id = uuid5(NAMESPACE_URL, f"nrc:{raw_id}")
    name = activity.get("tags", {}).get("com.nike.name") or "Corrida do Nike Run Club"
    return {
        "id": str(run_id),
        "request_id": raw_id or str(run_id),
        "name": name,
        "track": track,
    }
