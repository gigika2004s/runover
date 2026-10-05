/// Implementação fora da web: token só em memória (nunca persiste).
String? _memoryToken;

void saveToken(String token) {
  _memoryToken = token;
}

String? loadToken() => _memoryToken;

void clearToken() {
  _memoryToken = null;
}
