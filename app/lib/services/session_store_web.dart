import 'package:web/web.dart' as web;

/// Implementação web: `sessionStorage` da aba (sobrevive ao recarregar,
/// morre ao fechar a página).
const _tokenKey = 'runover_token';

void saveToken(String token) {
  try {
    web.window.sessionStorage.setItem(_tokenKey, token);
  } catch (_) {
    // sessionStorage indisponível: sem persistência alguma nesta sessão.
  }
}

String? loadToken() {
  try {
    return web.window.sessionStorage.getItem(_tokenKey);
  } catch (_) {
    return null;
  }
}

void clearToken() {
  try {
    web.window.sessionStorage.removeItem(_tokenKey);
  } catch (_) {}
}
