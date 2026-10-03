import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';

enum AuthStatus { unknown, signedOut, signedIn, unavailable }

class AppState extends ChangeNotifier {
  final ApiClient api;
  AppState({ApiClient? api}) : api = api ?? ApiClient();
  String? connectionError;

  AuthStatus status = AuthStatus.unknown;
  UserProfile? profile;

  Future<void> bootstrap() async {
    status = AuthStatus.unknown;
    connectionError = null;
    notifyListeners();
    try {
      await api.loadToken();
      if (api.isAuthenticated) {
        profile = await api.getMyProfile();
        status = AuthStatus.signedIn;
      } else {
        status = AuthStatus.signedOut;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await api.logout();
        status = AuthStatus.signedOut;
      } else {
        connectionError = e.message;
        status = AuthStatus.unavailable;
      }
    } catch (_) {
      connectionError =
          'Não foi possível carregar sua sessão. Tente novamente.';
      status = AuthStatus.unavailable;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await api.login(email: email, password: password);
    status = AuthStatus.signedIn;
    try {
      profile = await api.getMyProfile();
      _retryPendingClaimsQuietly();
    } on ApiException catch (e) {
      if (e.statusCode == 401) rethrow;
      profile = null;
    }
    notifyListeners();
  }

  Future<void> register(
    String fullName,
    String username,
    String email,
    String password, {
    String? photoUrl,
  }) async {
    await api.register(
      fullName: fullName,
      username: username,
      email: email,
      password: password,
      photoUrl: photoUrl,
    );
    profile = await api.getMyProfile();
    status = AuthStatus.signedIn;
    _retryPendingClaimsQuietly();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await api.getMyProfile();
    notifyListeners();
  }

  Future<void> retryPendingClaims() async {
    if (profile == null) {
      try {
        profile = await api.getMyProfile();
        notifyListeners();
      } catch (_) {
        return;
      }
    }
    final userId = profile?.id;
    if (userId == null) return;
    await api.retryPendingClaims(userId);
    await refreshProfile();
  }

  void _retryPendingClaimsQuietly() {
    final userId = profile?.id;
    if (userId == null) return;
    api
        .retryPendingClaims(userId)
        .then((_) => refreshProfile())
        .catchError((_) {});
  }

  Future<void> logout() async {
    await api.logout();
    profile = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
