"""Add activity sharing preference to users.

Revision ID: 0006_user_activity_privacy
Revises: 0005_team_profile_photo
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


revision = "0006_user_activity_privacy"
down_revision = "0005_team_profile_photo"
branch_labels = None
depends_on = None


def upgrade() -> None:
    conn = op.get_bind()
    if "users" not in inspect(conn).get_table_names():
        return
    columns = {column["name"] for column in inspect(conn).get_columns("users")}
    if "share_activities" not in columns:
        op.add_column(
            "users",
            sa.Column(
                "share_activities",
                sa.Boolean(),
                nullable=False,
                server_default=sa.true(),
            ),
        )


def downgrade() -> None:
    conn = op.get_bind()
    if "users" in inspect(conn).get_table_names():
        columns = {column["name"] for column in inspect(conn).get_columns("users")}
        if "share_activities" in columns:
            op.drop_column("users", "share_activities")
