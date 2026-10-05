import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button.dart'
    as google_web;

class SocialAuth {
  SocialAuth._();

  static final SocialAuth instance = SocialAuth._();
  static const _googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const _appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

  final GoogleSignIn _google = GoogleSignIn.instance;
  Future<void>? _googleInitialization;

  Stream<GoogleSignInAuthenticationEvent> get googleEvents =>
      _google.authenticationEvents;

  bool get googleConfigured =>
      _googleClientId.isNotEmpty || _googleServerClientId.isNotEmpty;

  bool get appleConfigured =>
      !(kIsWeb || defaultTargetPlatform == TargetPlatform.android) ||
      (_appleServiceId.isNotEmpty && _appleRedirectUri.isNotEmpty);

  Future<void> initializeGoogle() {
    if (!googleConfigured) {
      throw const SocialAuthException(
        'O login Google ainda precisa dos IDs OAuth do projeto Google.',
      );
    }
    return _googleInitialization ??= _google.initialize(
      clientId: _googleClientId.isEmpty ? null : _googleClientId,
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
  }

  Future<String> signInGoogle() async {
    await initializeGoogle();
    final account = await _google.authenticate();
    return account.authentication.idToken ??
        (throw const SocialAuthException(
          'O Google não retornou um token de identidade. Confira a configuração OAuth.',
        ));
  }

  Future<String> signInApple() async {
    if (!appleConfigured) {
      throw const SocialAuthException(
        'Configure o Service ID e a URL de retorno da Apple para habilitar este login.',
      );
    }
    final options = kIsWeb || defaultTargetPlatform == TargetPlatform.android
        ? WebAuthenticationOptions(
            clientId: _appleServiceId,
            redirectUri: Uri.parse(_appleRedirectUri),
          )
        : null;
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      webAuthenticationOptions: options,
    );
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw const SocialAuthException(
        'A Apple não retornou um token de identidade. Confira a configuração do app.',
      );
    }
    return token;
  }

  Widget buildGoogleWebButton() => google_web.buildGoogleWebButton();
}

class SocialAuthException implements Exception {
  const SocialAuthException(this.message);
  final String message;
}
