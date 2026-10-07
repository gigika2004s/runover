# Política de Segurança

## Como relatar uma vulnerabilidade

**Use o reporte privado do GitHub**: abra a aba **Security** do repositório e clique em **Report a vulnerability**. O relato vai só para os mantenedores, sem exposição pública.

Inclua, se possível:

- Descrição do problema e impacto estimado (o que um invasor conseguiria fazer).
- Passos para reproduzir (requests, telas, configurações).
- Versão/commit afetado e ambiente (produção, local, Android, Web).
- Logs ou respostas relevantes **sem** incluir tokens, senhas ou dados reais de usuários.

## Prazos

- Confirmação de recebimento em até **3 dias úteis**.
- Avaliação inicial e plano em até **15 dias**.
- Correção publicada assim que validada; advisories de severidade alta ou crítica têm prioridade sobre features.

## Escopo

Vale para código deste repositório (app Flutter, API FastAPI, deploy e workflows). Fora de escopo: serviços de terceiros (Render, Neon, Google, OSM), engenharia social e ataques de negação de serviço contra produção.

## Regras do jogo

- Não acesse, altere nem exponha dados de outros usuários além do mínimo para demonstrar o problema.
- Não divulgue a falha publicamente antes da correção (divulgação coordenada).
- Testes automatizados agressivos (fuzzing, varredura) só contra instância local, nunca contra produção.
- Pesquisadores de boa-fé seguindo esta política não serão penalizados; não operamos programa pago de recompensas.

## Versões suportadas

Correções de segurança saem na `main` (produção). Branches de trabalho não recebem backports.
