# Executar o RUNOVER!

## Requisitos

- Python 3.12.10.
- Flutter 3.47.2 e Dart 3.13.2.
- Git disponível no PATH.
- Para Android: JDK 17, Android SDK e licenças aceitas no ambiente local.

Os comandos abaixo partem da raiz do repositório, salvo indicação diferente.

## 1. Backend

### Linux ou macOS

```bash
python -m venv backend/.venv
backend/.venv/bin/python -m pip install -r backend/requirements-dev.txt
cd backend
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### Windows — PowerShell

```powershell
py -3.12 -m venv backend\.venv
.\backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt
cd backend
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

A API fica em `http://127.0.0.1:8000`, com documentação em `/docs` e
verificação de disponibilidade em `/health`.

Por padrão, o banco SQLite `runover.db` é criado no diretório de execução.
Na primeira inicialização são cadastrados territórios de exemplo em Embu
das Artes e no Parque Ibirapuera. Contas de usuário não são criadas
automaticamente; use o cadastro do aplicativo.

As variáveis de ambiente e as instruções de atualização estão em
[NOVA_VERSAO.md](NOVA_VERSAO.md). Preserve o banco existente ao atualizar.

## 2. Aplicativo web

Em outro terminal, na pasta `app/`:

```bash
flutter pub get --enforce-lockfile
flutter build web --dart-define=API_BASE=http://127.0.0.1:8000
```

Na raiz do repositório, sirva o build:

```bash
python -m http.server 5000 --bind 127.0.0.1 --directory app/build/web
```

No Windows, pode ser usado `py -3.12` no lugar de `python`.
Abra `http://127.0.0.1:5000` no navegador.

## 3. Android na rede local

1. Inicie o backend na pasta `backend/`, trocando `--host 127.0.0.1` por
   `--host 0.0.0.0` no comando correspondente ao sistema operacional.
2. Conecte computador e celular à mesma rede.
3. Identifique o IP local do computador e permita conexões à porta 8000
   no firewall da rede usada para o teste.
4. Na pasta `app/`, gere o APK, substituindo o endereço de exemplo pelo IP
   do computador:

   ```bash
   flutter build apk --release --dart-define=API_BASE=http://192.168.1.72:8000
   ```

5. Instale `app/build/app/outputs/flutter-apk/app-release.apk` no celular.
   Se estiver usando depuração USB, execute da pasta `app/`:

   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

6. Crie uma conta, permita o acesso à localização e abra **Mapa → Iniciar
   corrida**. Mantenha o aplicativo aberto durante a gravação.

O endereço da API fica incorporado ao APK. Se mudar, gere um novo build.
Para um backend publicado, use sua URL HTTPS em `API_BASE`.

O build release atual usa a chave de debug e serve para testes. Configure
uma chave de assinatura própria antes da distribuição definitiva.

## 4. Testes

Backend, a partir da raiz, em Linux ou macOS:

```bash
PYTHONPATH=backend backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

No Windows, execute a partir da pasta `backend/`:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Aplicativo, a partir de `app/`:

```bash
flutter analyze
flutter test
flutter build web
```

A arquitetura está em [ARQUITETURA.md](ARQUITETURA.md). As regras de
corrida, persistência e atualização estão em [NOVA_VERSAO.md](NOVA_VERSAO.md).
