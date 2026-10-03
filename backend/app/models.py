import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    username: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)  # RN02
    email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String, nullable=False)  # RNF01
    photo_url: Mapped[str | None] = mapped_column(String, nullable=True)  # RF01 — foto de perfil
    is_public: Mapped[bool] = mapped_column(default=True)  # RF05 — configuração de privacidade / RN13
    play_seconds: Mapped[int] = mapped_column(Integer, default=0)  # RF19 — tempo de jogo acumulado
    accepted_terms_at: Mapped[datetime] = mapped_column(DateTime, default=_now)  # RN01
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Team(Base):
    """Equipe — RF16/RN14/RN15, UC10 (Criar/Participar de equipe)."""

    __tablename__ = "teams"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    creator_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    creator: Mapped["User"] = relationship()
    members: Mapped[list["TeamMember"]] = relationship(back_populates="team")


class TeamMember(Base):
    __tablename__ = "team_members"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    team_id: Mapped[str] = mapped_column(ForeignKey("teams.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    team: Mapped["Team"] = relationship(back_populates="members")
    user: Mapped["User"] = relationship()


class Territory(Base):
    __tablename__ = "territories"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String, nullable=False)
    # GeoJSON Polygon serializado como texto — ver app/geometry.py (substitui PostGIS no protótipo local)
    geojson: Mapped[str] = mapped_column(Text, nullable=False)
    radius_m: Mapped[float] = mapped_column(Float, nullable=False)  # UC11 — raio de conquista
    relevance: Mapped[int] = mapped_column(Integer, default=1)  # RN09 — peso na pontuação
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    ownerships: Mapped[list["TerritoryOwnership"]] = relationship(
        back_populates="territory", order_by="TerritoryOwnership.conquered_at"
    )


class TerritoryOwnership(Base):
    """Cada conquista gera uma nova linha — o dono atual é a mais recente (RF13/RN12).

    Dono é um usuário OU uma equipe (RN07/RN15), nunca os dois.
    """

    __tablename__ = "territory_ownership"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    territory_id: Mapped[str] = mapped_column(ForeignKey("territories.id"), nullable=False)
    owner_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    owner_team_id: Mapped[str | None] = mapped_column(ForeignKey("teams.id"), nullable=True)
    points: Mapped[int] = mapped_column(Integer, nullable=False)  # RN09
    conquered_at: Mapped[datetime] = mapped_column(DateTime, default=_now, index=True)

    territory: Mapped["Territory"] = relationship(back_populates="ownerships")
    owner_user: Mapped["User | None"] = relationship()
    owner_team: Mapped["Team | None"] = relationship()


class ScoreEvent(Base):
    """Histórico de conquista/perda — RF13, RN12 (Historico no diagrama de classes)."""

    __tablename__ = "score_events"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    team_id: Mapped[str | None] = mapped_column(ForeignKey("teams.id"), nullable=True)
    territory_id: Mapped[str | None] = mapped_column(ForeignKey("territories.id"), nullable=True)
    delta: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=False)  # "conquista" | "perda"
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, index=True)

    user: Mapped["User | None"] = relationship()
    team: Mapped["Team | None"] = relationship()
    territory: Mapped["Territory | None"] = relationship()


class Notification(Base):
    """RF18/RN16, UC "Receber Notificação"."""

    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    message: Mapped[str] = mapped_column(String, nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False)  # "conquista" | "perda" | "ranking"
    is_read: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, index=True)

    user: Mapped["User"] = relationship()


class LocationPing(Base):
    """Geolocalização — RF14/RNF20: histórico de posições para auditoria."""

    __tablename__ = "location_pings"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime, default=_now, index=True)


class PasswordResetToken(Base):
    """One-time password reset token stored only as a digest."""

    __tablename__ = "password_reset_tokens"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    token_hash: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)

    user: Mapped["User"] = relationship()


class ClaimReceipt(Base):
    """Persists successful claim responses so network retries cannot score twice."""

    __tablename__ = "claim_receipts"
    __table_args__ = (UniqueConstraint("user_id", "request_id", name="uq_claim_user_request"),)

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
    request_id: Mapped[str] = mapped_column(String, nullable=False)
    payload_hash: Mapped[str] = mapped_column(String, nullable=False)
    response_json: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, nullable=False)
