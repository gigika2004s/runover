"""Catálogo do mercado interno (moedas + cosméticos).

O catálogo é versionado em código (sem painel admin no MVP): cada item tem
`id`, `category`, `name`, `price` (em moedinhas) e um `payload` com os dados
visuais que o app usa para renderizar (cores, emoji, asset, animação).

Categorias:
- `avatar`: decorações de avatar da galeria pronta (`asset`) ou gerados
  via DiceBear (`generated` = estilo, seed = apelido do dono) — os
  `animated` ganham animação no app sem precisar de GIF/WebP.
- `frame`: molduras de perfil.
- `effect`: efeitos de perfil (partículas/brilho animados no app).
- `banner`: placas de identificação — faixas de perfil (gradiente).
- `name_style`: placas de identificação — estilo do nome exibido.
- `emoticon`: pacotes de emoticons exibidos no perfil.
- `bundle`: pacotes com vários itens por um preço menor (compra libera
  cada item do `payload['grants']`).

Seções da loja no app (biblioteca com categorias): Decorações de avatar,
Placas de Identificação, Efeitos de perfil, Molduras de Perfil, Pacotes,
Disponíveis com Orbs (moedinhas ganhas correndo) e Parcerias
(`payload['collection'] == 'parceria').

Loja da equipe (`scope == 'team'`): decoração, molduras, efeitos, faixas e
estilos de nome da equipe, com valores altos em pontos. O saldo é o cofre
da equipe — soma dos pontos dos integrantes menos o já gasto (`spent_points`);
ninguém perde nível ou posição ao comprar. Compra e equipamento só pelo
dono ou admins; ver `app/services/team_shop.py` e as rotas em `/teams`.
"""

from __future__ import annotations

CATEGORIES = ("avatar", "frame", "effect", "banner", "name_style", "emoticon", "bundle")
SCOPES = ("user", "team", "pass")
ORB_COLLECTION = "orbs"  # tudo se compra com Orbs (moedinhas ganhas correndo)
PARTNER_COLLECTION = "parceria"

# Equipamento usa uma coluna por categoria (exceto emoticons, que é lista).
EQUIPPABLE = ("avatar", "frame", "effect", "banner", "name_style")


def _item(
    item_id: str,
    category: str,
    name: str,
    price: int,
    scope: str = "user",
    **payload,
) -> dict:
    return {
        "id": item_id,
        "category": category,
        "name": name,
        "price": price,
        "scope": scope,
        "payload": payload,
    }


CATALOG_BASE: list[dict] = [
    # ---- Avatares da galeria pronta (assets/avatars) ----
    # Tudo custa moedas: nenhum item tem preço 0 (a galeria do app compra
    # e equipa estes mesmos itens — sem bypass gratuito).
    _item("avatar_corredor", "avatar", "Corredor", 50, asset="corredor", animated=False),
    _item("avatar_coroa", "avatar", "Coroa", 150, asset="coroa", animated=False),
    _item("avatar_raio", "avatar", "Raio animado", 400, asset="raio", animated=True),
    _item("avatar_chama", "avatar", "Chama animada", 600, asset="chama", animated=True),
    _item("avatar_sol", "avatar", "Sol", 180, asset="sol", animated=False),
    _item("avatar_lua", "avatar", "Lua", 180, asset="lua", animated=False),
    _item("avatar_onda", "avatar", "Onda", 220, asset="onda", animated=False),
    _item("avatar_pico", "avatar", "Pico", 220, asset="pico", animated=False),
    _item("avatar_estrela", "avatar", "Estrela", 300, asset="estrela", animated=False),
    _item("avatar_bandeira", "avatar", "Bandeira", 300, asset="bandeira", animated=False),
    _item("avatar_cometa", "avatar", "Cometa animado", 450, asset="cometa", animated=True),
    _item("avatar_escudo", "avatar", "Escudo", 350, asset="escudo", animated=False),
    # ---- Avatares gerados (DiceBear, gratuito sem chave; seed = apelido) ----
    _item("avatar_gerado_adventurer", "avatar", "Gerado aventureiro", 250, generated="adventurer", animated=False),
    _item("avatar_gerado_avataaars", "avatar", "Gerado avatar", 250, generated="avataaars", animated=False),
    _item("avatar_gerado_bottts", "avatar", "Gerado robô", 300, generated="bottts", animated=False),
    _item("avatar_gerado_personas", "avatar", "Gerado persona", 350, generated="personas", animated=False),
    _item("avatar_gerado_notionists", "avatar", "Gerado notion", 400, generated="notionists", animated=False),
    _item("avatar_gerado_thumbs", "avatar", "Gerado polegar", 450, generated="thumbs", animated=False),
    _item("avatar_gerado_pixel_art", "avatar", "Gerado pixel", 500, generated="pixel-art", animated=False),
    _item("avatar_gerado_lorelei", "avatar", "Gerado lorelei", 600, generated="lorelei", animated=False),
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
    # ---- Loja da equipe (scope team, valores altos em pontos) ----
    _item("team_avatar_estandarte", "avatar", "Estandarte da equipe", 4000, "team", asset="bandeira", animated=False),
    _item("team_avatar_escudo", "avatar", "Escudo da equipe", 6000, "team", asset="escudo", animated=False),
    _item("team_avatar_coroa", "avatar", "Coroa da equipe", 9000, "team", asset="coroa", animated=False),
    _item("team_avatar_cometa", "avatar", "Cometa da equipe", 12000, "team", asset="cometa", animated=True),
    _item("team_avatar_chama", "avatar", "Chama da equipe", 18000, "team", asset="chama", animated=True),
    _item("team_frame_ferro", "frame", "Moldura ferro da equipe", 5000, "team", colors=["#57534E"], animated=False),
    _item("team_frame_prata", "frame", "Moldura prata da equipe", 8000, "team", colors=["#E5E7EB"], animated=False),
    _item("team_frame_ouro", "frame", "Moldura ouro da equipe", 12000, "team", colors=["#FFC93C", "#FF7F4D"], animated=False),
    _item("team_frame_fogo", "frame", "Moldura fogo da equipe", 20000, "team", colors=["#EF4444", "#F59E0B"], animated=True),
    _item("team_frame_lendaria", "frame", "Moldura lendária da equipe", 30000, "team", colors=["#8B5CF6", "#3DDBB0", "#FFC93C"], animated=True),
    _item("team_effect_faisca", "effect", "Faíscas da equipe", 8000, "team", kind="sparkle", animated=True),
    _item("team_effect_chamas", "effect", "Chamas da equipe", 15000, "team", kind="fire", animated=True),
    _item("team_effect_tormenta", "effect", "Tormenta da equipe", 25000, "team", kind="sparkle", animated=True, variant=2),
    _item("team_effect_inferno", "effect", "Inferno da equipe", 40000, "team", kind="fire", animated=True, variant=2),
    _item("team_banner_bau", "banner", "Faixa baú da equipe", 6000, "team", colors=["#92400E", "#F59E0B"]),
    _item("team_banner_muralha", "banner", "Faixa muralha da equipe", 10000, "team", colors=["#57534E", "#A8A29E"]),
    _item("team_banner_horizonte", "banner", "Faixa horizonte da equipe", 16000, "team", colors=["#0EA5E9", "#8B7CFF"]),
    _item("team_banner_tempestade", "banner", "Faixa tempestade da equipe", 25000, "team", colors=["#1E1B4B", "#6366F1", "#22D3EE"]),
    _item("team_banner_gloria", "banner", "Faixa glória da equipe", 40000, "team", colors=["#FFC93C", "#FF7F4D", "#8B5CF6"]),
    _item("team_name_guerreiro", "name_style", "Nome guerreiro da equipe", 5000, "team", colors=["#E5E7EB"], glow=False),
    _item("team_name_capitao", "name_style", "Nome capitão da equipe", 9000, "team", colors=["#3DDBB0"], glow=True),
    _item("team_name_lenda", "name_style", "Nome lenda da equipe", 14000, "team", colors=["#FFC93C"], glow=True),
    _item("team_name_mito", "name_style", "Nome mito da equipe", 22000, "team", colors=["#FF7F4D", "#FFC93C", "#3DDBB0", "#8B7CFF"], glow=True),
    _item("team_pacote_batalha", "bundle", "Pacote batalha da equipe", 45000, "team",
          grants=["team_frame_ferro", "team_effect_faisca", "team_banner_bau"]),
    _item("team_pacote_gloria", "bundle", "Pacote glória da equipe", 80000, "team",
          grants=["team_frame_ouro", "team_effect_chamas", "team_name_lenda"]),
    # ---- Pass Runover (scope pass, impossíveis de comprar: só o resgate
    # da temporada concede; preço 0 nunca aparece em vitrine com filtro).
    _item("pass_banner_pioneiro", "banner", "Faixa pioneira do passe", 0, "pass",
          colors=["#3DDBB0", "#0EA5E9"]),
    _item("pass_frame_pioneiro", "frame", "Moldura pioneira do passe", 0, "pass",
          colors=["#3DDBB0"], animated=False),
    _item("pass_effect_pioneiro", "effect", "Faíscas pioneiras do passe", 0, "pass",
          kind="sparkle", animated=False),
    _item("pass_avatar_explorador", "avatar", "Explorador do passe", 0, "pass",
          generated="adventurer", animated=False),
    _item("pass_name_capitao", "name_style", "Nome capitão do passe", 0, "pass",
          colors=["#0EA5E9"], glow=True),
    _item("pass_banner_conquistador", "banner", "Faixa conquistadora do passe", 0, "pass",
          colors=["#FF7F4D", "#FFC93C"]),
    _item("pass_frame_conquistador", "frame", "Moldura conquistadora do passe", 0, "pass",
          colors=["#FF7F4D", "#FFC93C"], animated=False),
    _item("pass_effect_tormenta", "effect", "Tormenta do passe", 0, "pass",
          kind="sparkle", animated=False, variant=3),
    _item("pass_name_lenda", "name_style", "Nome lenda do passe", 0, "pass",
          colors=["#8B7CFF", "#FFC93C"], glow=True),
]

# ---------------------------------------------------------------------------
# Expansão da biblioteca: +100 opções novas por categoria, sem repetidos.
# O catálogo continua versionado em código e 100% orientado a dados: o app
# renderiza tudo a partir do `payload` (cores, emoji, asset, animação), então
# nenhum binário novo é necessário. IDs e nomes são únicos por construção
# (ver `_assert_unique` abaixo — falha no boot em vez de duplicar na loja).
# Itens base acima são preservados com preço/ID estáveis para não quebrar
# inventários existentes nem os testes.
# ---------------------------------------------------------------------------

_EXTRA_PER_CATEGORY = 100

_AVATAR_ASSETS = (
    "corredor", "coroa", "raio", "chama", "sol", "lua", "onda", "pico",
    "estrela", "bandeira", "cometa", "escudo",
)
_AVATAR_THEMES = (
    "Ambar", "Aurora", "Boreal", "Ciclone", "Delta", "Eclipse", "Falcão",
    "Guepardo", "Horizonte", "Ímpeto", "Jato", "Krypton", "Litoral", "Monção",
    "Neblina", "Olimpo", "Pampa", "Quasar", "Rastro", "Sprint", "Trovão",
    "Ultramar", "Vento", "Xingu", "Zênite",
)

_FRAME_PALETTES = (
    ["#EF4444"], ["#F97316"], ["#F59E0B"], ["#84CC16"], ["#22C55E"],
    ["#14B8A6"], ["#06B6D4"], ["#3B82F6"], ["#6366F1"], ["#8B5CF6"],
    ["#A855F7"], ["#D946EF"], ["#EC4899"], ["#F43F5E"], ["#78716C"],
    ["#EF4444", "#F59E0B"], ["#22C55E", "#06B6D4"], ["#3B82F6", "#8B5CF6"],
    ["#EC4899", "#F59E0B"], ["#14B8A6", "#3B82F6"], ["#F43F5E", "#8B5CF6"],
    ["#84CC16", "#06B6D4"], ["#F97316", "#EC4899"], ["#6366F1", "#22C55E"],
    ["#06B6D4", "#8B5CF6", "#EC4899"],
)

_BANNER_THEMES = (
    "Amanhecer", "Arrecife", "Asfalto", "Caatinga", "Cerrado", "Chapada",
    "Cordilheira", "Deserto", "Enseada", "Floresta", "Geleira", "Ilha",
    "Jangada", "Lagoa", "Mangue", "Maré", "Montanha", "Pantanal", "Praia",
    "Recife", "Rio", "Savana", "Serra", "Tempestade", "Vulcão",
)

_NAME_THEMES = (
    "Aço", "Âmbar", "Basalto", "Bronze", "Caramelo", "Carmesim", "Céu",
    "Cobre", "Coral", "Cristal", "Esmeralda", "Grafite", "Jade", "Lilás",
    "Magenta", "Marfim", "Menta", "Níquel", "Ônix", "Opala", "Petróleo",
    "Platina", "Rubi", "Safira", "Topázio",
)

_EMOJI_POOL = (
    "🏆", "🥇", "🥈", "🥉", "🏅", "⚡", "🔥", "💧", "🌊", "⛰️", "🏔️", "🌋",
    "🌅", "🌇", "🌈", "❄️", "💨", "🌪️", "🎯", "🚀", "🛰️", "🧭", "⌚", "👟",
    "🎽", "🚴", "🏊", "🧗", "🤸", "💪", "🦵", "❤️", "💚", "💙", "💜", "🖤",
    "⭐", "🌟", "✨", "💫", "👑",
)

_BUNDLE_THEMES = (
    "Trilha", "Velocidade", "Resistência", "Conquista", "Exploração",
    "Maratona", "Meia-maratona", "Intervalado", "Fartlek", "Longão",
    "Montanha", "Cidade", "Parque", "Praia", "Noturno", "Aurora",
    "Tempestade", "Nevoeiro", "Horizonte", "Cume", "Vale", "Rio", "Lago",
    "Floresta", "Deserto",
)


def _extra_avatars() -> list[dict]:
    items = []
    for i in range(_EXTRA_PER_CATEGORY):
        asset = _AVATAR_ASSETS[i % len(_AVATAR_ASSETS)]
        theme = _AVATAR_THEMES[(i // len(_AVATAR_ASSETS)) % len(_AVATAR_THEMES)]
        animated = (i % 3 == 2)
        items.append(_item(
            f"avatar_galeria_{i + 1:03d}", "avatar",
            f"{theme} {asset.capitalize()} {i + 1:03d}",
            60 + (i * 17) % 1400,
            asset=asset, animated=animated, variant=i + 1,
        ))
    return items


def _extra_frames() -> list[dict]:
    items = []
    for i in range(_EXTRA_PER_CATEGORY):
        colors = list(_FRAME_PALETTES[i % len(_FRAME_PALETTES)])
        items.append(_item(
            f"frame_colecao_{i + 1:03d}", "frame",
            f"Moldura coleção {i + 1:03d}",
            90 + (i * 23) % 1500,
            colors=colors, animated=(i % 4 == 3),
        ))
    return items


def _extra_effects() -> list[dict]:
    kinds = ("sparkle", "fire")
    labels = ("Fagulhas", "Brasas")
    items = []
    for i in range(_EXTRA_PER_CATEGORY):
        kind = kinds[i % 2]
        items.append(_item(
            f"effect_inedito_{i + 1:03d}", "effect",
            f"{labels[i % 2]} {i + 1:03d}",
            120 + (i * 29) % 1500,
            kind=kind, animated=True, variant=i + 1,
        ))
    return items


def _extra_banners() -> list[dict]:
    items = []
    for i in range(_EXTRA_PER_CATEGORY):
        theme = _BANNER_THEMES[i % len(_BANNER_THEMES)]
        base = list(_FRAME_PALETTES[(i * 7) % len(_FRAME_PALETTES)])
        items.append(_item(
            f"banner_paisagem_{i + 1:03d}", "banner",
            f"{theme} {i + 1:03d}",
            110 + (i * 19) % 1400,
            colors=base,
        ))
    return items


def _extra_name_styles() -> list[dict]:
    items = []
    for i in range(_EXTRA_PER_CATEGORY):
        theme = _NAME_THEMES[i % len(_NAME_THEMES)]
        base = list(_FRAME_PALETTES[(i * 5) % len(_FRAME_PALETTES)][:2])
        items.append(_item(
            f"name_estilo_{i + 1:03d}", "name_style",
            f"Nome {theme.lower()} {i + 1:03d}",
            130 + (i * 21) % 1400,
            colors=base, glow=(i % 2 == 0),
        ))
    return items


def _extra_emoticons() -> list[dict]:
    items = []
    used: set[tuple] = set()
    i = 0
    n = 0
    while n < _EXTRA_PER_CATEGORY:
        size = 1 + (i % 3)
        combo = tuple(sorted(
            _EMOJI_POOL[(i * 7 + k * 13) % len(_EMOJI_POOL)] for k in range(size)
        ))
        i += 1
        if combo in used:
            continue
        used.add(combo)
        n += 1
        items.append(_item(
            f"emoticon_pacote_{n:03d}", "emoticon",
            f"Pacote {n:03d}",
            80 + ((n * 31) % 900),
            emoji=list(combo),
        ))
    return items


def _extra_bundles() -> list[dict]:
    items = []
    for i in range(_EXTRA_PER_CATEGORY):
        theme = _BUNDLE_THEMES[i % len(_BUNDLE_THEMES)]
        a = 1 + ((i * 3) % _EXTRA_PER_CATEGORY)
        f = 1 + ((i * 5 + 1) % _EXTRA_PER_CATEGORY)
        b = 1 + ((i * 7 + 2) % _EXTRA_PER_CATEGORY)
        grants = [f"avatar_galeria_{a:03d}", f"frame_colecao_{f:03d}", f"banner_paisagem_{b:03d}"]
        prices = (
            60 + ((a - 1) * 17) % 1400,
            90 + ((f - 1) * 23) % 1500,
            110 + ((b - 1) * 19) % 1400,
        )
        price = max(200, round(sum(prices) * 0.8))
        items.append(_item(
            f"pacote_trilha_{i + 1:03d}", "bundle",
            f"Pacote {theme.lower()} {i + 1:03d}",
            price, grants=grants,
        ))
    return items


def _assert_unique(catalog: list[dict]) -> None:
    ids = [i["id"] for i in catalog]
    names = [(i["category"], i["name"]) for i in catalog]
    dup_ids = sorted({v for v in ids if ids.count(v) > 1})
    dup_names = sorted({v for v in names if names.count(v) > 1})
    if dup_ids or dup_names:
        raise ValueError(f"Catálogo com repetidos: ids={dup_ids} nomes={dup_names}")


CATALOG: list[dict] = (
    list(CATALOG_BASE)
    + _extra_avatars()
    + _extra_frames()
    + _extra_effects()
    + _extra_banners()
    + _extra_name_styles()
    + _extra_emoticons()
    + _extra_bundles()
)

# Política da loja: nada estático — todo item nasce animado no app
# (brilho, partículas ou respiração conforme a categoria).
for _entry in CATALOG:
    _entry["payload"]["animated"] = True

_assert_unique(CATALOG)

BY_ID = {item["id"]: item for item in CATALOG}


def get_item(item_id: str) -> dict | None:
    return BY_ID.get(item_id)


def list_items(category: str | None = None, scope: str | None = None) -> list[dict]:
    items = CATALOG
    if scope is not None:
        items = [i for i in items if i.get("scope", "user") == scope]
    if category is None:
        return list(items)
    return [i for i in items if i["category"] == category]


def team_items() -> list[dict]:
    """Catálogo da loja da equipe (escopo team, valores altos)."""
    return [i for i in CATALOG if i.get("scope") == "team"]


def free_items() -> list[dict]:
    return [i for i in CATALOG if i["price"] == 0]
