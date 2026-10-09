"""Cor de destaque do perfil: gratuita, validada e visível para todos."""


def _auth(registered_user):
    return {"Authorization": f"Bearer {registered_user['token']}"}


def test_accent_color_roundtrip_and_normalization(client, registered_user):
    headers = _auth(registered_user)
    assert client.get("/users/me", headers=headers).json()["accent_color"] is None

    updated = client.patch(
        "/users/me", json={"accent_color": "#ff7f4d"}, headers=headers
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["accent_color"] == "#FF7F4D"

    # Visível no perfil público e na exportação.
    username = updated.json()["username"]
    public = client.get(f"/users/{username}", headers=headers).json()
    assert public["accent_color"] == "#FF7F4D"
    export = client.get("/users/me/export", headers=headers).json()
    assert export["account"]["accent_color"] == "#FF7F4D"

    # Limpa com null.
    cleared = client.patch("/users/me", json={"accent_color": None}, headers=headers)
    assert cleared.status_code == 200
    assert cleared.json()["accent_color"] is None


def test_accent_color_rejects_invalid(client, registered_user):
    headers = _auth(registered_user)
    for bad in ("red", "#FFF", "#GGGGGG", "FF7F4D", "#FF7F4D00", 123):
        response = client.patch(
            "/users/me", json={"accent_color": bad}, headers=headers
        )
        assert response.status_code == 422, bad
    assert client.get("/users/me", headers=headers).json()["accent_color"] is None
