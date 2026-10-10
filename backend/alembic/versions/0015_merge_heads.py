"""Unir o histórico das insígnias com o dos ajustes da equipe.

Os dois ramos saíram de `0012_pass_runover`: o nosso abriu
`0013_user_badges` -> `0014_team_invites`, e a main abriu
`0013_drop_accent_color` -> `0014_team_settings`. Nenhuma coluna nova aqui;
só fecha a bifurcação para o `upgrade head` ter um destino.
"""

revision = "0015_merge_heads"
down_revision = ("0014_team_invites", "0014_team_settings")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
