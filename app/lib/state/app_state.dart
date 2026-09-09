import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();

  AuthStatus status = AuthStatus.unknown;
  UserProfile? profile;

  Future<void> bootstrap() async {
    await api.loadToken();
    if (api.isAuthenticated) {
      try {
        profile = await api.getMyProfile();
        status = AuthStatus.signedIn;
      } catch (_) {
        await api.logout();
        status = AuthStatus.signedOut;
      }
    } else {
      status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await api.login(email: email, password: password);
    profile = await api.getMyProfile();
    status = AuthStatus.signedIn;
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
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await api.getMyProfile();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    profile = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
