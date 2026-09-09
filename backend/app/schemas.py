from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


def _validate_password(v: str) -> str:
    # RN03 — mínimo 8 caracteres, letras e números
    if len(v) < 8 or not any(c.isalpha() for c in v) or not any(c.isdigit() for c in v):
        raise ValueError("A senha deve ter no mínimo 8 caracteres, incluindo letras e números.")
    return v


# ---------- Autenticação (RF01-RF04) ----------

class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2)
    username: str = Field(min_length=3, max_length=24)
    email: EmailStr
    password: str
    photo_url: str | None = None  # RF01 — foto de perfil (opcional)
    accept_terms: bool  # RF02 / RN01

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        return _validate_password(v)

    @field_validator("accept_terms")
    @classmethod
    def validate_terms(cls, v: bool) -> bool:
        if not v:
            raise ValueError("É necessário aceitar os termos de uso e a política de privacidade.")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    reset_token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        return _validate_password(v)


# ---------- Usuário / Perfil (RF05, RF17, RF19) ----------

class ProfileUpdateRequest(BaseModel):
    full_name: str | None = None
    username: str | None = Field(default=None, min_length=3, max_length=24)
    photo_url: str | None = None
    password: str | None = None
    is_public: bool | None = None  # RF05 — configuração de privacidade


class UserPublic(BaseModel):
    username: str
    photo_url: str | None
    total_score: int
    territories_count: int
    rank_position: int | None
    team_name: str | None = None
    # RF11 / RN10 — progressão
    level: int
    level_progress: float  # 0..1 — fração até o próximo nível
    points_to_next_level: int


class UserProfile(UserPublic):
    id: str
    full_name: str
    email: str
    created_at: datetime
    is_public: bool  # RF05
    play_seconds: int  # RF19 — tempo de jogo


# ---------- Equipes (RF16, RN14, RN15) ----------

class TeamCreateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=40)


class TeamMemberInfo(BaseModel):
    username: str
    photo_url: str | None


class TeamSummary(BaseModel):
    id: str
    name: str
    creator_username: str
    member_count: int


class TeamDetail(TeamSummary):
    members: list[TeamMemberInfo]
    total_score: int
    territories_count: int
    # RF11 / RN10 — progressão da equipe (mesma curva do jogador)
    level: int
    level_progress: float
    points_to_next_level: int


# ---------- Territórios (RF06-RF09) ----------

class LatLng(BaseModel):
    lat: float
    lng: float


class TrackPoint(LatLng):
    timestamp: datetime


class TerritorySummary(BaseModel):
    id: str
    name: str
    coordinates: list[LatLng]  # anel externo do polígono, para desenhar no mapa
    center: LatLng
    radius_m: float
    status: str  # "disponivel" | "conquistado"
    owner_type: str | None  # "user" | "team"
    owner_display: str | None  # apelido do usuário ou nome da equipe dona


class TerritoryDetail(TerritorySummary):
    conquered_at: datetime | None
    points_value: int


class ClaimRequest(BaseModel):
    # Mecânica estilo Strava: o trajeto inteiro, do início ao fim — precisa
    # fechar um laço (RN05) pra virar ou retomar um território.
    track: list[TrackPoint]
    team_id: str | None = None  # RN15 — se informado, o território vai para a equipe
    name: str | None = None  # nome do território, se o laço criar um novo


class ClaimResponse(BaseModel):
    territory: TerritoryDetail
    created_new: bool  # true = o laço não sobrepôs nenhum território existente
    points_awarded: int
    area_m2: float
    new_total_score: int
    new_level: int  # RF11 — nível após a conquista
    leveled_up: bool  # RF11 / RN16 — subiu de nível nesta conquista


# ---------- Geolocalização (RF14 / RNF20) ----------

class LocationPingRequest(BaseModel):
    lat: float
    lng: float


# ---------- Ranking e histórico (RF12, RF13) ----------

class RankingEntry(BaseModel):
    position: int
    owner_type: str  # "user" | "team"
    name: str
    photo_url: str | None
    total_score: int
    territories_count: int
    level: int  # RF11 / RN10


class HistoryEntry(BaseModel):
    territory_name: str | None
    delta: int
    reason: str
    created_at: datetime


# ---------- Notificações (RF18, RN16) ----------

class NotificationEntry(BaseModel):
    id: str
    message: str
    type: str
    is_read: bool
    created_at: datetime
