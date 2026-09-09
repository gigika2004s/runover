import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Cliente da API do RUNOVER!.
///
/// O endereço da API vem de `--dart-define=API_BASE=...` no build. Sem isso,
/// usa localhost (web/desktop). Exemplos:
///   - celular na mesma Wi-Fi:  --dart-define=API_BASE=http://192.168.1.72:8000
///   - emulador Android:        --dart-define=API_BASE=http://10.0.2.2:8000
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const _tokenKey = 'runover_token';

  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  bool get isAuthenticated => _token != null;

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  dynamic _unwrap(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    String message = 'Erro inesperado (${res.statusCode}).';
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        // erro de validação do Pydantic
        message = detail.map((e) => e['msg']).join('\n');
      }
    }
    throw ApiException(message);
  }

  // ---------- Autenticação ----------

  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    String? photoUrl,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': password,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
        'accept_terms': true,
      }),
    );
    final data = _unwrap(res);
    await _saveToken(data['access_token']);
  }

  Future<void> login({required String email, required String password}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _unwrap(res);
    await _saveToken(data['access_token']);
  }

  Future<String> requestPasswordReset(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
    final data = _unwrap(res);
    return data['reset_token'] ?? '';
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: _headers,
      body: jsonEncode({'reset_token': resetToken, 'new_password': newPassword}),
    );
    _unwrap(res);
  }

  // ---------- Perfil ----------

  Future<UserProfile> getMyProfile() async {
    final res = await http.get(Uri.parse('$baseUrl/users/me'), headers: _headers);
    return UserProfile.fromJson(_unwrap(res));
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? username,
    String? password,
    String? photoUrl,
    bool? isPublic,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: _headers,
      body: jsonEncode({
        if (fullName != null) 'full_name': fullName,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
        if (photoUrl != null) 'photo_url': photoUrl.isEmpty ? null : photoUrl,
        if (isPublic != null) 'is_public': isPublic,
      }),
    );
    return UserProfile.fromJson(_unwrap(res));
  }

  Future<List<HistoryEntry>> getMyHistory() async {
    final res = await http.get(Uri.parse('$baseUrl/users/me/history'), headers: _headers);
    final data = _unwrap(res) as List;
    return data.map((e) => HistoryEntry.fromJson(e)).toList();
  }

  /// RF17 — perfil público de outro jogador. Lança [ApiException] com a
  /// mensagem "Este perfil é privado." quando o back-end responde 403.
  Future<PublicProfile> getPublicProfile(String username) async {
    final res = await http.get(Uri.parse('$baseUrl/users/$username'), headers: _headers);
    return PublicProfile.fromJson(_unwrap(res));
  }

  // ---------- Territórios ----------

  Future<List<Territory>> listTerritories() async {
    final res = await http.get(Uri.parse('$baseUrl/territories'), headers: _headers);
    final data = _unwrap(res) as List;
    return data.map((e) => Territory.fromJson(e)).toList();
  }

  Future<TerritoryDetail> getTerritory(String id) async {
    final res = await http.get(Uri.parse('$baseUrl/territories/$id'), headers: _headers);
    return TerritoryDetail.fromJson(_unwrap(res));
  }

  /// Mecânica estilo Strava: envia o trajeto inteiro; se ele fechar um laço
  /// sobre um território existente, retoma-o — senão, cria um novo ali.
  Future<Map<String, dynamic>> claimTerritory(
    List<Map<String, dynamic>> track, {
    String? teamId,
    String? name,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/territories/claim'),
      headers: _headers,
      body: jsonEncode({
        'track': track,
        if (teamId != null) 'team_id': teamId,
        if (name != null) 'name': name,
      }),
    );
    return _unwrap(res);
  }

  // ---------- Ranking ----------

  Future<List<RankingEntry>> getRanking() async {
    final res = await http.get(Uri.parse('$baseUrl/ranking'), headers: _headers);
    final data = _unwrap(res) as List;
    return data.map((e) => RankingEntry.fromJson(e)).toList();
  }

  // ---------- Equipes ----------

  Future<List<TeamSummary>> listTeams() async {
    final res = await http.get(Uri.parse('$baseUrl/teams'), headers: _headers);
    final data = _unwrap(res) as List;
    return data.map((e) => TeamSummary.fromJson(e)).toList();
  }

  Future<TeamDetail> createTeam(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/teams'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return TeamDetail.fromJson(_unwrap(res));
  }

  Future<TeamDetail?> getMyTeam() async {
    final res = await http.get(Uri.parse('$baseUrl/teams/mine'), headers: _headers);
    if (res.statusCode == 404) return null;
    return TeamDetail.fromJson(_unwrap(res));
  }

  Future<TeamDetail> joinTeam(String teamId) async {
    final res = await http.post(Uri.parse('$baseUrl/teams/$teamId/join'), headers: _headers);
    return TeamDetail.fromJson(_unwrap(res));
  }

  Future<void> leaveTeam() async {
    final res = await http.post(Uri.parse('$baseUrl/teams/leave'), headers: _headers);
    if (res.statusCode != 204) _unwrap(res);
  }

  // ---------- Notificações ----------

  Future<List<NotificationEntry>> getNotifications() async {
    final res = await http.get(Uri.parse('$baseUrl/notifications'), headers: _headers);
    final data = _unwrap(res) as List;
    return data.map((e) => NotificationEntry.fromJson(e)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    final res = await http.patch(Uri.parse('$baseUrl/notifications/$id/read'), headers: _headers);
    _unwrap(res);
  }

  // ---------- Geolocalização ----------

  Future<void> pingLocation(double lat, double lng) async {
    await http.post(
      Uri.parse('$baseUrl/location'),
      headers: _headers,
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
  }
}
