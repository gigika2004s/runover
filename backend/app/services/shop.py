"""Catálogo do mercado interno (moedas + cosméticos estilo Discord).

O catálogo é versionado em código (sem painel admin no MVP): cada item tem
`id`, `category`, `name`, `price` (em moedinhas) e um `payload` com os dados
visuais que o app usa para renderizar (cores, emoji, asset, animação).

Categorias:
- `avatar`: decorações de avatar da galeria pronta (`asset`) — os
  `animated` ganham animação no app sem precisar de GIF/WebP.
- `frame`: molduras de perfil.
- `effect`: efeitos de perfil (partículas/brilho animados no app).
- `banner`: placas de identificação — faixas de perfil (gradiente).
- `name_style`: placas de identificação — estilo do nome exibido.
- `emoticon`: pacotes de emoticons exibidos no perfil.
- `bundle`: pacotes com vários itens por um preço menor (compra libera
  cada item do `payload['grants']`).

Seções da loja no app (biblioteca estilo Discord): Decorações de avatar,
Placas de Identificação, Efeitos de perfil, Molduras de Perfil, Pacotes,
Disponíveis com Orbs (moedinhas ganhas correndo) e Parcerias
(`payload['collection'] == 'parceria'`).
"""

from __future__ import annotations

CATEGORIES = ("avatar", "frame", "effect", "banner", "name_style", "emoticon", "bundle")
ORB_COLLECTION = "orbs"  # tudo se compra com Orbs (moedinhas ganhas correndo)
PARTNER_COLLECTION = "parceria"

# Equipamento usa uma coluna por categoria (exceto emoticons, que é lista).
EQUIPPABLE = ("avatar", "frame", "effect", "banner", "name_style")


def _item(
    item_id: str,
    category: str,
    name: str,
    price: int,
    **payload,
) -> dict:
    return {
        "id": item_id,
        "category": category,
        "name": name,
        "price": price,
        "payload": payload,
    }


CATALOG: list[dict] = [
    # ---- Avatares da galeria pronta (assets/avatars) ----
    _item("avatar_corredor", "avatar", "Corredor", 0, asset="corredor", animated=False),
    _item("avatar_coroa", "avatar", "Coroa", 150, asset="coroa", animated=False),
    _item("avatar_raio", "avatar", "Raio animado", 400, asset="raio", animated=True),
    _item("avatar_chama", "avatar", "Chama animada", 600, asset="chama", animated=True),
    # ---- Molduras ----
    _item("frame_bronze", "frame", "Moldura bronze", 100, colors=["#CD7F32"], animated=False),
    _item("frame_prata", "frame", "Moldura prata", 250, colors=["#C0C0C0"], animated=False),
    _item("frame_ouro", "frame", "Moldura ouro", 500, colors=["#FFC93C", "#FF7F4D"], animated=False),
    _item("frame_neon", "frame", "Moldura neon animada", 800, colors=["#3DDBB0", "#8B7CFF"], animated=True),
    # ---- Efeitos de perfil ----
    _item("effect_faísca", "effect", "Faíscas", 300, kind="sparkle", animated=True),
    _item("effect_chamas", "effect", "Chamas", 600, kind="fire", animated=True),
    # ---- Faixas de perfil ----
    _item("banner_oceano", "banner", "Oceano", 200, colors=["#0EA5E9", "#1E3A8A"]),
    _item("banner_pôr_do_sol", "banner", "Pôr do sol", 350, colors=["#FF7F4D", "#8B7CFF"]),
    _item("banner_galáxia", "banner", "Galáxia", 600, colors=["#2A2240", "#8B7CFF", "#3DDBB0"]),
    # ---- Estilos de nome ----
    _item("name_neon", "name_style", "Nome neon", 250, colors=["#3DDBB0"], glow=True),
    _item("name_ouro", "name_style", "Nome ouro", 400, colors=["#FFC93C"], glow=True),
    _item("name_arco_íris", "name_style", "Nome arco-íris", 700, colors=["#FF7F4D", "#FFC93C", "#3DDBB0", "#8B7CFF"], glow=False),
    # ---- Emoticons exibidos no perfil ----
    _item("emoticon_troféu", "emoticon", "Troféu", 150, emoji=["🏆"]),
    _item("emoticon_raio", "emoticon", "Raio", 150, emoji=["⚡"]),
    _item("emoticon_campeão", "emoticon", "Pacote campeão", 400, emoji=["🏆", "🔥", "⚡", "🏅"]),
    # ---- Parcerias ----
    _item("frame_torcida", "frame", "Moldura torcida (parceria)", 450,
          colors=["#16A34A", "#FFC93C"], animated=False, collection="parceria"),
    _item("banner_torcida", "banner", "Faixa torcida (parceria)", 400,
          colors=["#16A34A", "#FFFFFF"], collection="parceria"),
    _item("emoticon_torcida", "emoticon", "Pacote torcida (parceria)", 250,
          emoji=["📣", "🎉", "💚"], collection="parceria"),
    # ---- Pacotes (preço menor que a soma) ----
    _item("pacote_iniciante", "bundle", "Pacote iniciante", 350,
          grants=["avatar_coroa", "frame_bronze", "banner_oceano"]),
    _item("pacote_campeão", "bundle", "Pacote campeão", 900,
          grants=["frame_ouro", "effect_faísca", "name_ouro"]),
]

BY_ID = {item["id"]: item for item in CATALOG}


def get_item(item_id: str) -> dict | None:
    return BY_ID.get(item_id)


def list_items(category: str | None = None) -> list[dict]:
    if category is None:
        return list(CATALOG)
    return [i for i in CATALOG if i["category"] == category]


def free_items() -> list[dict]:
    return [i for i in CATALOG if i["price"] == 0]
