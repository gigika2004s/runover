import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/home_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> teamJson() => {
  'id': 't1',
  'name': 'Trovão',
  'photo_url': null,
  'creator_username': 'marina',
  'member_count': 5,
  'members': [
    {
      'username': 'marina',
      'photo_url': null,
      'is_admin': true,
      'is_online': true,
    },
    {
      'username': 'joao',
      'photo_url': null,
      'is_admin': false,
      'is_online': true,
    },
  ],
  'total_score': 900,
  'territories_count': 7,
  'level': 3,
  'level_progress': 0.5,
  'points_to_next_level': 100,
  'is_owner': true,
  'is_admin': true,
  'my_request': null,
  'pending_requests': [
    {
      'id': 'r1',
      'username': 'novo',
      'photo_url': null,
      'created_at': '2026-01-01T00:00:00Z',
    },
  ],
  'online_count': 2,
};

Map<String, dynamic> progressJson() => {
  'week_start': '2026-10-05T00:00:00Z',
  'runs_count': 3,
  'distance_km': 21.5,
  'longest_run_km': 8.4,
  'goals': [],
  'badges': [],
  'team': null,
  'fastest_pace_seconds_per_km': 332,
};

MockClient cardDataClient() => MockClient((request) async {
  if (request.url.path == '/teams/mine') {
    return http.Response(jsonEncode(teamJson()), 200);
  }
  if (request.url.path == '/runs/progress') {
    return http.Response(jsonEncode(progressJson()), 200);
  }
  return http.Response('[]', 200);
});

void main() {
  testWidgets('map tab opens on a light start screen without loading the map', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var territoryRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.startsWith('/territories')) territoryRequests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson({
        'id': '1',
        'full_name': 'Marina Oliveira',
        'username': 'marina',
        'email': 'marina@example.com',
        'photo_url': null,
        'total_score': 0,
        'territories_count': 0,
        'rank_position': null,
        'team_name': null,
        'level': 1,
        'level_progress': 0,
        'points_to_next_level': 100,
        'is_public': true,
        'play_seconds': 0,
      });
    addTearDown(state.dispose);
    var menuOpened = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: HomeScreen(onOpenMenu: () => menuOpened = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ESCOLHA SEU MODO'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(territoryRequests, 0);

    await tester.tap(find.byTooltip('Menu'));
    expect(menuOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows game mode cards with real stats', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(client: cardDataClient());
    addTearDown(api.close);
    final state = AppState(api: api);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder verticalScrollable() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.vertical,
    );

    expect(find.text('ESCOLHA SEU MODO'), findsOneWidget);
    expect(find.text('DOMINAÇÃO DE TERRITÓRIOS'), findsOneWidget);
    expect(find.text('DESAFIO DE VELOCIDADE F1'), findsOneWidget);
    // Velocidade: dados reais do progresso (nada de recorde inventado).
    expect(find.text('3 corridas'), findsOneWidget);
    expect(find.text('recorde 8,4 km'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PIT STOP DE EQUIPE'),
      200,
      scrollable: verticalScrollable(),
    );
    expect(find.text('PIT STOP DE EQUIPE'), findsOneWidget);
    // Equipe: dados reais (membros, online, pedidos pendentes).
    expect(find.text('5 membros'), findsOneWidget);
    expect(find.text('2 online'), findsOneWidget);
    expect(find.text('Nv 3'), findsOneWidget);
    expect(find.text('1 PEDIDO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode cards show retry on load failure, not empty states', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final profileJson = {
      'id': '1',
      'full_name': 'Marina Oliveira',
      'username': 'marina',
      'email': 'marina@example.com',
      'photo_url': null,
      'total_score': 0,
      'territories_count': 0,
      'rank_position': null,
      'team_name': null,
      'level': 1,
      'level_progress': 0,
      'points_to_next_level': 100,
      'is_public': true,
      'play_seconds': 0,
    };
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/users/me') {
          return http.Response(jsonEncode(profileJson), 200);
        }
        return http.Response('erro', 500);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileJson);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Erro não pode se passar por "sem equipe" nem "sem corridas".
    await tester.scrollUntilVisible(
      find.text('ESCOLHA SEU MODO'),
      500,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      ),
    );
    expect(find.text('Falha ao carregar'), findsWidgets);
    expect(find.text('Sem equipe'), findsNothing);
    expect(find.text('Nenhuma corrida'), findsNothing);
    await tester.ensureVisible(find.text('TENTAR DE NOVO').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TENTAR DE NOVO').first);
    await tester.pumpAndSettle();
    expect(find.text('Falha ao carregar'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode cards keep content and action visible at large text scale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    // A HomeScreen recarrega o perfil no initState: o mock serve o mesmo
    // perfil exibido para que o refresh não troque os dados sob o teste.
    final profileJson = {
      'id': '1',
      'full_name': 'Marina Oliveira',
      'username': 'marina',
      'email': 'marina@example.com',
      'photo_url': null,
      'total_score': 0,
      'territories_count': 12,
      'rank_position': 3,
      'team_name': null,
      'level': 1,
      'level_progress': 0,
      'points_to_next_level': 100,
      'is_public': true,
      'play_seconds': 0,
    };
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/users/me') {
          return http.Response(jsonEncode(profileJson), 200);
        }
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(teamJson()), 200);
        }
        if (request.url.path == '/runs/progress') {
          return http.Response(jsonEncode(progressJson()), 200);
        }
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileJson);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A lista vertical é lazy: em escala grande a seção de modos só é
    // construída após rolar até ela.
    await tester.scrollUntilVisible(
      find.text('ESCOLHA SEU MODO'),
      500,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      ),
    );
    expect(find.text('ESCOLHA SEU MODO'), findsOneWidget);
    expect(find.text('12 zonas suas'), findsOneWidget);
    expect(find.text('Ranking #3'), findsOneWidget);
    expect(find.text('3 corridas'), findsOneWidget);
    expect(find.text('recorde 8,4 km'), findsOneWidget);
    // Cards are in a row on wide screens, column on narrow. Test uses narrow (390px).
    // Scroll to the buttons.
    await tester.scrollUntilVisible(
      find.text('JOGAR'),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      ),
    );
    expect(find.text('JOGAR'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PIT STOP DE EQUIPE'),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      ),
    );
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.text('5 membros'), findsOneWidget);
    expect(find.text('2 online'), findsOneWidget);
    expect(find.text('1 PEDIDO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
