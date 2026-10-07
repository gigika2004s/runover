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

    expect(find.text('Iniciar corrida'), findsOneWidget);
    expect(find.text('Ver mapa de territórios'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(territoryRequests, 0);

    await tester.tap(find.byTooltip('Menu'));
    expect(menuOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows game mode cards with domination playable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(
      client: MockClient((request) async => http.Response('[]', 200)),
    );
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

    expect(find.text('Escolha seu modo'), findsOneWidget);
    expect(find.text('Dominação de territórios'), findsOneWidget);
    expect(find.text('Desafio de velocidade F1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pit stop de equipe'),
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.horizontal,
      ),
    );
    expect(find.text('Pit stop de equipe'), findsOneWidget);
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

    Finder horizontalScrollable() => find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.horizontal,
    );

    // TODO(debug-ci): remover após diagnosticar o finder no CI.
    debugPrint(
      'HOME-DEBUG profile zones=${state.profile?.territoriesCount} '
      'rank=${state.profile?.rankPosition}',
    );
    debugPrint(
      'HOME-DEBUG texts=${find.byType(Text).evaluate().map((e) {
        final w = e.widget as Text;
        return w.data ?? w.textSpan?.toPlainText();
      }).toList()}',
    );
    expect(find.text('12 zonas suas'), findsOneWidget);
    expect(find.text('Ranking #3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Jogar'),
      200,
      scrollable: horizontalScrollable(),
    );
    expect(find.text('Jogar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pit stop de equipe'),
      200,
      scrollable: horizontalScrollable(),
    );
    expect(find.text('Entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
