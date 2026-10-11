import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/season_pass_screen.dart';
import 'package:runover_app/season_pass/demo_season.dart';
import 'package:runover_app/season_pass/models.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

Future<void> openSeason(
  WidgetTester tester, {
  Season? season,
  Future<void> Function(int level, RewardLane lane)? onClaim,
  VoidCallback? onOpenPass,
  // Larga o bastante para as 7 colunas existirem de uma vez (a trilha é lazy).
  Size size = const Size(1400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildRunoverTheme(),
      home: SeasonPassScreen(
        season: season ?? demoSeason(),
        onClaim: onClaim,
        onOpenPass: onOpenPass,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('os quatro estados aparecem e o banner do passe é exibido', (
    tester,
  ) async {
    await openSeason(tester);
    expect(find.text('Temporada Aurora'), findsOneWidget);
    expect(find.text('Nível 4'), findsOneWidget);
    // 1–3 grátis resgatadas, 4 grátis resgatável.
    expect(find.text('Resgatado'), findsNWidgets(3));
    expect(find.text('Resgatar'), findsOneWidget);
    // Faixa do passe sem passe: níveis alcançados pedem o passe.
    expect(find.text('Requer passe'), findsNWidgets(4));
    // Níveis 5–7 bloqueados nas duas faixas.
    expect(find.text('Nível 5'), findsNWidgets(2));
    expect(find.text('Nível 6'), findsNWidgets(2));
    expect(find.text('Nível 7'), findsNWidgets(2));
    expect(find.textContaining('Só itens visuais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resgatar muda o estado na hora e chama onClaim', (tester) async {
    RewardLane? gotLane;
    int? gotLevel;
    await openSeason(
      tester,
      onClaim: (level, lane) async {
        gotLevel = level;
        gotLane = lane;
      },
    );
    await tester.tap(find.text('Resgatar'));
    await tester.pumpAndSettle();
    expect(gotLevel, 4);
    expect(gotLane, RewardLane.free);
    expect(find.text('Resgatar'), findsNothing);
    expect(find.text('Resgatado'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro no resgate desfaz o estado e mostra mensagem', (
    tester,
  ) async {
    await openSeason(
      tester,
      onClaim: (level, lane) async => throw Exception('falhou'),
    );
    await tester.tap(find.text('Resgatar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível resgatar. Tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Resgatar'), findsOneWidget);
    expect(find.text('Resgatado'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('com passe não há banner nem "Requer passe"', (tester) async {
    final demo = demoSeason();
    final season = Season(
      name: demo.name,
      endsAt: demo.endsAt,
      levels: demo.levels,
      currentLevel: demo.currentLevel,
      points: demo.points,
      pointsForNext: demo.pointsForNext,
      hasPass: true,
      claimed: demo.claimed,
    );
    await openSeason(tester, season: season);
    expect(find.text('Requer passe'), findsNothing);
    expect(find.textContaining('Só itens visuais'), findsNothing);
    // Nível 4 do passe vira resgatável junto da grátis — e o mesmo vale
    // para a faixa do passe dos níveis 1–3 já alcançados.
    expect(find.text('Resgatar'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('em 360 px abre sem overflow', (tester) async {
    await openSeason(tester, size: const Size(360, 740));
    // A página (vertical) é a primeira lista; a segunda é a trilha horizontal.
    await tester.scrollUntilVisible(
      find.text('Ver passe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ver passe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resgate persistido com refresh falho recarrega em vez de reofertar',
    (tester) async {
      // Regressão: o POST persistiu, mas o refresh do perfil falhou — a tela
      // recarrega do servidor (que já marca resgatado) em vez de deixar o
      // botão levar a um 409.
      var passFetches = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'GET' && path == '/pass') {
            passFetches++;
            return http.Response(
              jsonEncode({
                'season_id': '2026-10',
                'ends_at': '2026-11-01T00:00:00+00:00',
                'seasonal_points': 250,
                'unlocked_tier': 1,
                'premium_unlocked': false,
                'premium_price_coins': 1000,
                'tiers': [
                  {
                    'tier': 1,
                    'threshold': 200,
                    'unlocked': true,
                    'free': {'coins': 10, 'item_id': null, 'claimed': false},
                    'premium': {
                      'coins': 25,
                      'item_id': null,
                      'claimed': false,
                    },
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'GET' && path == '/shop/catalog') {
            return http.Response(jsonEncode([]), 200);
          }
          if (request.method == 'POST' && path == '/pass/claim') {
            return http.Response(jsonEncode({}), 200);
          }
          if (path == '/users/me') {
            return http.Response(
              jsonEncode({'detail': 'Perfil indisponível.'}),
              500,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(api.close);
      final state = AppState(api: api)
        ..profile = UserProfile.fromJson(profileData);
      addTearDown(state.dispose);
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: buildRunoverTheme(),
            home: const SeasonPassScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(passFetches, 1);

      await tester.tap(find.text('Resgatar'));
      await tester.pumpAndSettle();
      // Carregamento inicial + recarga pós-falha (sem ela, seria só 1).
      expect(passFetches, 2);
      expect(find.text('Perfil indisponível.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
