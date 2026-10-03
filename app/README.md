# RUNOVER — aplicativo

Aplicativo Flutter para registrar corridas, conquistar territórios e
acompanhar o progresso individual e das equipes.

## Ambiente

- Flutter 3.47.2.
- Dart 3.13.2.
- Backend RUNOVER acessível por HTTP no desenvolvimento ou HTTPS no servidor.

## Desenvolvimento

Na pasta `app/`:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --dart-define=API_BASE=http://127.0.0.1:8000
```

O parâmetro `API_BASE` define o endereço do backend no build. Para testar
no celular, use um endereço acessível pelo aparelho.

Consulte [o guia de execução](../RODAR.md),
[a arquitetura](../ARQUITETURA.md) e
[as regras de corridas e atualização](../NOVA_VERSAO.md).

A documentação do framework está em [docs.flutter.dev](https://docs.flutter.dev/).
