# Como rodar o RUNOVER!

Ambiente já instalado nesta máquina (set. 2026):

- **Python 3.12** → `C:\Users\gio\AppData\Local\Programs\Python\Python312`
- **Flutter 3.47.2** → `C:\Users\gio\flutter`
- **Git 2.55** → `C:\Program Files\Git`
- venv do backend → `backend\venv` (já com as dependências instaladas)

Se algum sumir de novo, veja a seção 11.1 do `SESSAO.md` para reinstalar.

---

## 1. Back-end (FastAPI + SQLite)

```powershell
cd C:\Users\gio\Downloads\runover\backend
.\venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

- API em `http://127.0.0.1:8000` — documentação interativa em `/docs`.
- Na primeira execução o `runover.db` é criado e os territórios de exemplo
  (Embu das Artes + Ibirapuera) são populados.
- Para zerar tudo: pare o servidor, apague `backend\runover.db`, suba de novo.

## 2. App Flutter — build web servido estaticamente (jeito estável)

```powershell
$env:Path = "C:\Users\gio\flutter\bin;C:\Program Files\Git\cmd;" + $env:Path
cd C:\Users\gio\Downloads\runover\app
flutter build web
cd build\web
C:\Users\gio\Downloads\runover\backend\venv\Scripts\python.exe -m http.server 5000 --bind 127.0.0.1
```

Abra `http://127.0.0.1:5000` no navegador.

> `flutter run -d edge` funciona para desenvolvimento, mas a conexão de debug
> (DWDS) com o Edge é instável nesta máquina — por isso o build estático.

## 2b. Testar no celular Android (APK, GPS real)

Toolchain Android instalada nesta máquina:

- JDK 17 → `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot`
- Android SDK → `C:\Users\gio\Android\Sdk` (`flutter config` já aponta pra ele)

O celular fala com o back-end pela rede Wi-Fi, então:

1. **Back-end ouvindo na rede** (não só localhost):
   ```powershell
   cd C:\Users\gio\Downloads\runover\backend
   .\venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
2. **Liberar a porta 8000 no Firewall** (uma vez, num PowerShell **como administrador**):
   ```powershell
   New-NetFirewallRule -DisplayName "RUNOVER API 8000" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow -Profile Private
   ```
   (ou aceite o prompt do Firewall que aparece quando o uvicorn sobe pela 1ª vez)
3. **Descobrir o IP do PC na Wi-Fi**: `ipconfig` → "Endereço IPv4" (ex.: `192.168.1.72`). O celular precisa estar na **mesma rede**.
4. **Gerar o APK** apontando pro IP do PC:
   ```powershell
   $env:Path = "C:\Users\gio\flutter\bin;C:\Program Files\Git\cmd;C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin;" + $env:Path
   cd C:\Users\gio\Downloads\runover\app
   flutter build apk --release --dart-define=API_BASE=http://192.168.1.72:8000
   ```
   Saída: `build\app\outputs\flutter-apk\app-release.apk`
5. **Instalar no celular**: copie o `.apk` pro telefone (cabo/Drive/WhatsApp Web) e abra pra instalar (precisa permitir "fontes desconhecidas"). Ou, com depuração USB ligada:
   ```powershell
   C:\Users\gio\Android\Sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-release.apk
   ```
6. No app, permita o acesso à **localização** quando pedir. Entre com `demo@runover.com` / `demo12345`, abra o **Mapa** → **Iniciar corrida**, ande um quarteirão e volte ao ponto de partida pra fechar o laço e dominar a área.

> Se o app abrir mas não logar: o celular não está alcançando `http://IP-DO-PC:8000`
> — confira mesma Wi-Fi, o `--host 0.0.0.0` e a regra de Firewall.
> O `API_BASE` fica gravado no APK; se o IP do PC mudar, gere o APK de novo.

## 3. Testes

```powershell
# App
cd C:\Users\gio\Downloads\runover\app
flutter analyze
flutter test

# Back-end — teste ponta a ponta rápido (com o servidor no ar)
#   registro -> níveis -> conquista com laço fechado -> notificações -> ranking
```

## 4. O que está implementado

Todos os 19 RF do `.docx`. Os itens desta última rodada:

| Requisito | Onde |
|---|---|
| RF11 / RN10 — níveis e progressão | selo "Nv N" + barra no perfil, ranking, perfil público e equipe; notificação de level-up |
| RF17 — perfil de outro jogador | toque num nome do ranking → `public_profile_screen.dart` |
| RF02 / RNF02 — termos + LGPD | `terms_screen.dart`, linkado no cadastro e no perfil |
| RF05 — privacidade + foto | switch "Perfil público" e campo de foto (URL) na edição de perfil; perfil privado responde 403 a terceiros |
| RF19 — tempo de jogo | card "Tempo de jogo" no perfil (soma da duração das corridas) |
| RF18 — mudança de ranking | notificação quando a posição do usuário muda após uma conquista |

Fora do escopo (infraestrutura): GPS em segundo plano real, carga de 1.000
usuários, PostgreSQL/PostGIS, builds Android/iOS, push via FCM. Ver
`SESSAO.md` seção 10.
