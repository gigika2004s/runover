import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/edit_profile_screen.dart';
import 'package:runover_app/screens/profile_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/cosmetics.dart';

import 'profile_screen_test.dart' show profileData, progressData;

void main() {
  test('parse valida hexadecimal e ignora o resto', () {
    expect(parseAccentColor('#ff7f4d'), const Color(0xFFFF7F4D));
    expect(parseAccentColor('#FF7F4D'), const Color(0xFFFF7F4D));
    expect(parseAccentColor(null), isNull);
    expect(parseAccentColor(''), isNull);
    expect(parseAccentColor('red'), isNull);
    expect(parseAccentColor('#FFF'), isNull);
    expect(parseAccentColor('#GGGGGG'), isNull);
    expect(parseAccentColor('FF7F4D'), isNull);
  });

  test('faixa padrão deriva da cor e some sem cor', () {
    expect(accentBannerGradient(null), isNull);
    expect(accentBannerGradient('invalida'), isNull);
    final gradient = accentBannerGradient('#FF7F4D')!;
    expect(gradient.colors.first, const Color(0xFFFF7F4D));
    expect(gradient.colors.length, 2);
  });

  testWidgets('nome usa a cor de destaque sem estilo equipado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          return http.Response(jsonEncode(progressData), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson({
        ...profileData,
        'accent_color': '#FF7F4D',
      });
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = tester.widget<Text>(find.text('Marina Oliveira'));
    expect(name.style?.color, const Color(0xFFFF7F4D));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor salva a cor de destaque no perfil', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? patched;
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/users/me');
        patched = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({...profileData, 'accent_color': '#FF7F4D'}),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileData)
      ..status = AuthStatus.signedIn;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(profile: state.profile!),
                  ),
                ),
                child: const Text('Abrir editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    expect(find.text('Cor de destaque'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accent-swatch-#FF7F4D')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(patched?['accent_color'], '#FF7F4D');
    expect(state.profile?.accentColor, '#FF7F4D');
    expect(tester.takeException(), isNull);
  });
}
