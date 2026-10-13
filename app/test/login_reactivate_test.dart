import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/screens/login_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/services/social_auth.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

class _FakeSocialAuth implements SocialAuth {
  @override
  Stream<GoogleSignInAuthenticationEvent> get googleEvents =>
      const Stream.empty();

  @override
  bool get googleConfigured => false;

  @override
  Future<void> initializeGoogle() async {}

  @override
  Future<String> signInGoogle() async => 'fake-id-token-0123456789';

  @override
  Widget buildGoogleWebButton() => const SizedBox();
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<List> openLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = [];
    final api = ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path == '/auth/login') {
          calls.add('login');
          return http.Response(
            jsonEncode({
              'detail': 'Esta conta está desativada. Reative-a para continuar.',
            }),
            403,
          );
        }
        if (request.method == 'POST' && path == '/auth/reactivate') {
          calls.add('reactivate');
          return http.Response(
            jsonEncode({
              'access_token': 'token-reativado',
              'token_type': 'bearer',
            }),
            200,
          );
        }
        if (path == '/users/me') {
          return http.Response(jsonEncode(profileData), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await settle(tester);
    // Transiente de primeiro frame da tela de login (pré-existente, some
    // após o warmup das fontes). O takeException final continua valendo
    // para tudo que o fluxo sob teste renderizar.
    tester.takeException();
    await tester.enterText(
      find.widgetWithText(TextField, 'E-mail'),
      'marina@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Senha'),
      'original123',
    );
    await tester.tap(find.text('Entrar'));
    await settle(tester);
    return calls;
  }

  testWidgets('login desativado pergunta e reativa ao confirmar', (
    tester,
  ) async {
    final calls = await openLogin(tester);
    expect(find.text('Reativar conta?'), findsOneWidget);
    expect(
      find.text(
        'Sua conta está desativada. Deseja reativar a conta agora? '
        'Tudo volta como estava.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Reativar'));
    await settle(tester);
    expect(calls, ['login', 'reactivate']);
    expect(find.text('Reativar conta?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recusar mantém a conta desativada', (tester) async {
    final calls = await openLogin(tester);
    await tester.tap(find.text('Agora não'));
    await settle(tester);
    expect(calls, ['login']);
    expect(find.text('Reativar conta?'), findsNothing);
    expect(find.text('Reativar minha conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('botão reativar também pergunta antes', (tester) async {
    final calls = await openLogin(tester);
    await tester.tap(find.text('Agora não'));
    await settle(tester);
    await tester.tap(find.text('Reativar minha conta'));
    await settle(tester);
    expect(find.text('Reativar conta?'), findsOneWidget);
    await tester.tap(find.text('Reativar'));
    await settle(tester);
    expect(calls, ['login', 'reactivate']);
    expect(tester.takeException(), isNull);
  });

  Future<List> openSocialLogin(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => SocialAuth.debugOverride = null);
    SocialAuth.debugOverride = _FakeSocialAuth();
    final calls = [];
    final api = ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path == '/auth/oauth/google') {
          calls.add('oauth-login');
          return http.Response(
            jsonEncode({'detail': 'Esta conta está desativada.'}),
            403,
          );
        }
        if (request.method == 'POST' &&
            path == '/auth/oauth/google/reactivate') {
          calls.add('oauth-reactivate');
          expect(
            jsonDecode(request.body)['id_token'],
            'fake-id-token-0123456789',
          );
          return http.Response(
            jsonEncode({
              'access_token': 'token-reativado',
              'token_type': 'bearer',
            }),
            200,
          );
        }
        if (path == '/users/me') {
          return http.Response(jsonEncode(profileData), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const LoginScreen(),
        ),
      ),
    );
    await settle(tester);
    tester.takeException();
    await tester.tap(find.text('Continuar com Google'));
    await settle(tester);
    return calls;
  }

  testWidgets('login social desativado pergunta e reativa', (tester) async {
    final calls = await openSocialLogin(tester);
    expect(find.text('Reativar conta?'), findsOneWidget);

    await tester.tap(find.text('Reativar'));
    await settle(tester);
    expect(calls, ['oauth-login', 'oauth-reactivate']);
    expect(find.text('Reativar conta?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recusar no social mantém desativada', (tester) async {
    final calls = await openSocialLogin(tester);
    await tester.tap(find.text('Agora não'));
    await settle(tester);
    expect(calls, ['oauth-login']);
    expect(find.text('Reativar conta?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
