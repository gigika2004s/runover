import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Consentimento de cookies/armazenamento local (estilo Strava).
enum CookieChoice { acceptedAll, essentialOnly, customized }

class CookieConsent {
  const CookieConsent({
    required this.choice,
    this.analytics = false,
    this.marketing = false,
  });

  factory CookieConsent.acceptedAll() => const CookieConsent(
    choice: CookieChoice.acceptedAll,
    analytics: true,
    marketing: true,
  );

  factory CookieConsent.essentialOnly() =>
      const CookieConsent(choice: CookieChoice.essentialOnly);

  factory CookieConsent.fromJson(Map<String, dynamic> json) {
    final choice = CookieChoice.values.firstWhere(
      (c) => c.name == json['choice'],
      orElse: () => CookieChoice.essentialOnly,
    );
    return CookieConsent(
      choice: choice,
      analytics: json['analytics'] == true,
      marketing: json['marketing'] == true,
    );
  }

  final CookieChoice choice;
  final bool analytics;
  final bool marketing;

  Map<String, dynamic> toJson() => {
    'choice': choice.name,
    'analytics': analytics,
    'marketing': marketing,
  };
}

class CookieConsentStore {
  static const storageKey = 'runover_cookie_consent';

  static Future<CookieConsent?> load({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(storageKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return CookieConsent.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    CookieConsent consent, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setString(storageKey, jsonEncode(consent.toJson()));
  }
}
