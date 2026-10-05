import 'session_store_stub.dart'
    if (dart.library.js_interop) 'session_store_web.dart'
    as impl;

/// Guarda o token de acesso somente durante a sessão.
///
/// Na web usa `sessionStorage` (sobrevive ao recarregar, mas morre ao
/// fechar a aba); nas demais plataformas fica só em memória. Fechar a
/// página encerra o login — nada de sessão é persistido em disco.
class SessionStore {
  static void saveToken(String token) => impl.saveToken(token);
  static String? loadToken() => impl.loadToken();
  static void clearToken() => impl.clearToken();
}
