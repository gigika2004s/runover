# Configurar login Google

Os botões usam o backend do RUNOVER para verificar os tokens e abrir uma sessão da API. Nenhum segredo OAuth é guardado no app ou no Git.

## Google

1. No Google Cloud Console, crie credenciais OAuth para Web e Android.
2. Para Android, informe o identificador do app `com.runover.runover_app` e a impressão SHA-1 do certificado de desenvolvimento e do certificado de publicação.
3. Em **Render → serviço runover → Environment**, defina `GOOGLE_OAUTH_CLIENT_IDS` com os IDs de cliente aceitos pelo backend, separados por vírgula. Inclua o ID Web usado como server client ID.
4. Ao compilar o Flutter, passe os IDs públicos:
   - `--dart-define=GOOGLE_WEB_CLIENT_ID=<ID_WEB>`
   - `--dart-define=GOOGLE_SERVER_CLIENT_ID=<ID_WEB>`

O Google para Web mostra o botão oficial do SDK. Na Web, cadastre o endereço HTTPS do site como origem autorizada no Google Cloud.

## Tela de consentimento (verificação de propriedade)

Na tela de consentimento OAuth do Google Cloud, preencha:

- Domínios autorizados: `runover.onrender.com`
- Página inicial do app: `https://runover.onrender.com`
- URL da política de privacidade: `https://runover.onrender.com/privacidade`
- E-mail de suporte e contato do desenvolvedor: o e-mail da equipe

Como pedimos só perfil e e-mail básicos (sem escopos sensíveis), não há verificação formal estendida; enquanto o app estiver em modo de teste, adicione seu Gmail como usuário de teste.

Configurado em produção: ID Web `346362177621-g8li6h47ic6sot55p68700a0lgpqo01v.apps.googleusercontent.com` (vai no Dockerfile como `GOOGLE_WEB_CLIENT_ID` e `GOOGLE_SERVER_CLIENT_ID`) e ID Android `346362177621-oftb5ivv0vr0c0as2nadcqh59cpv17ur.apps.googleusercontent.com` (pacote `com.runover.runover_app`, SHA-1 de debug `AC:7A:C2:D2:C8:69:EE:EE:E1:0B:4C:F5:E0:F1:E6:9F:BF:0E:FD:D2`). Os dois entram em `GOOGLE_OAUTH_CLIENT_IDS` no Render, separados por vírgula; o ID Android não vai para o bundle Web.

## Contas já existentes

O backend não vincula uma conta social a uma conta antiga só porque os endereços de e-mail coincidem. Isso evita que o provedor social dê acesso a uma conta de senha sem comprovar as duas identidades. O vínculo manual pode ser adicionado depois com confirmação da sessão existente.
