import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/pass_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

Map<String, dynamic> passStatus({
  bool premium = false,
  bool claimedFree = false,
}) => {
  'season_id': '2026-10',
  'ends_at': '2026-11-01T00:00:00+00:00',
  'seasonal_points': 250,
  'unlocked_tier': 1,
  'premium_unlocked': premium,
  'premium_price_coins': 1000,
  'tiers': [
    {
      'tier': 1,
      'threshold': 200,
      'unlocked': true,
      'free': {
        'coins': 10,
        'item_id': null,
        'claimed': claimedFree,
      },
      'premium': {'coins': 25, 'item_id': null, 'claimed': false},
    },
    {
      'tier': 2,
      'threshold': 400,
      'unlocked': false,
      'free': {
        'coins': 20,
        'item_id': null,
        'claimed': false,
      },
      'premium': {'coins': 50, 'item_id': null, 'claimed': false},
    },
  ],
};

void main() {
  Future<List> openPass(
    WidgetTester tester, {
    bool premium = false,
    bool claimedFree = false,
  }) async {
    final calls = [];
    var premiumNow = premium;
    var claimedNow = claimedFree;
    final api = ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/pass') {
          return http.Response(
            jsonEncode(
              passStatus(premium: premiumNow, claimedFree: claimedNow),
            ),
            200,
          );
        }
        if (request.method == 'GET' && path == '/shop/catalog') {
          expect(request.url.queryParameters['scope'], 'pass');
          return http.Response(jsonEncode([]), 200);
        }
        if (request.method == 'POST' && path == '/pass/claim') {
          final body = jsonDecode(request.body);
          calls.add(('claim', body['tier'], body['track']));
          if (body['track'] == 'free') claimedNow = true;
          return http.Response(
            jsonEncode(
              passStatus(premium: premiumNow, claimedFree: claimedNow),
            ),
            200,
          );
        }
        if (request.method == 'POST' && path == '/pass/premium') {
          calls.add(('premium',));
          premiumNow = true;
          return http.Response(
            jsonEncode(
              passStatus(premium: premiumNow, claimedFree: claimedNow),
            ),
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
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileData);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const PassScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('mostra temporada, tiers e resgata a trilha grátis', (
    tester,
  ) async {
    final calls = await openPass(tester);
    expect(find.text('Pass Runover'), findsOneWidget);
    expect(find.textContaining('outubro de 2026'), findsOneWidget);
    expect(find.textContaining('250 XP'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Grátis'));
    await tester.pumpAndSettle();
    expect(calls, [('claim', 1, 'free')]);
    expect(find.text('Recompensa resgatada!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium desbloqueia com confirmação', (tester) async {
    final calls = await openPass(tester);
    expect(find.textContaining('1.000 moedas'), findsOneWidget);

    await tester.tap(find.textContaining('1.000 moedas'));
    await tester.pumpAndSettle();
    expect(find.text('Trilha premium?'), findsOneWidget);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(calls, [('premium',)]);
    expect(find.text('Trilha premium ativa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
