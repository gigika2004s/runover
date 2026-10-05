"""Baseline: esquema já criado pelo create_all.

Bancos existentes (incluindo produção) já têm todas as tabelas via
Base.metadata.create_all, então esta revisão propositalmente não altera
nada; ela só estabelece o histórico do alembic. ALTERs futuros (colunas
novas, índices) entram em novas revisões, aplicadas pelo
initialize_database na inicialização.
"""

revision = "0001_baseline"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
