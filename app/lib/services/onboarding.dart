import 'package:shared_preferences/shared_preferences.dart';

/// Marca se o tutorial inicial já foi visto (primeira abertura).
class OnboardingStore {
  static const storageKey = 'runover_onboarding_seen';

  static Future<bool> seen({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    return store.getBool(storageKey) ?? false;
  }

  static Future<void> markSeen({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setBool(storageKey, true);
  }
}
