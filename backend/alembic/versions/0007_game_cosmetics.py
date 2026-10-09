"""Add game coins, profile cosmetics and favorites."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0009_game_cosmetics"
down_revision = "0008_user_activity_privacy"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    inspector = inspect(conn)
    if "users" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("users")}
    if "pronouns" not in columns:
        op.add_column("users", sa.Column("pronouns", sa.String(80), nullable=True))
    if "coin_balance" not in columns:
        op.add_column("users", sa.Column("coin_balance", sa.Integer(), nullable=False, server_default="0"))
    if "equipped_cosmetics" not in columns:
        op.add_column("users", sa.Column("equipped_cosmetics", sa.String(), nullable=False, server_default=""))
    if "daily_mission_date" not in columns:
        op.add_column("users", sa.Column("daily_mission_date", sa.String(10), nullable=True))
    if "daily_mission_claimed" not in columns:
        op.add_column("users", sa.Column("daily_mission_claimed", sa.Boolean(), nullable=False, server_default=sa.false()))
    tables = inspector.get_table_names()
    for name in ("user_cosmetics", "user_favorites"):
        if name in tables:
            continue
        op.create_table(
            name,
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("user_id", sa.String(), sa.ForeignKey("users.id"), nullable=False),
            sa.Column("item_id", sa.String(64), nullable=False),
            *(
                [sa.Column("purchased_at", sa.DateTime(), nullable=False)]
                if name == "user_cosmetics"
                else []
            ),
            sa.UniqueConstraint("user_id", "item_id", name=f"uq_{name[:-1]}"),
        )
        op.create_index(f"ix_{name}_user_id", name, ["user_id"])


def downgrade() -> None:
    for name in ("user_favorites", "user_cosmetics"):
        op.drop_index(f"ix_{name}_user_id", table_name=name)
        op.drop_table(name)
    op.drop_column("users", "equipped_cosmetics")
    op.drop_column("users", "coin_balance")
    op.drop_column("users", "pronouns")
    op.drop_column("users", "daily_mission_claimed")
    op.drop_column("users", "daily_mission_date")
