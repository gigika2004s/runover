import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/runs_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('featured goal is the open goal closest to completion', () {
    const goals = [
      WeeklyGoal(name: 'km', value: 2, target: 10, unit: 'km'),
      WeeklyGoal(name: 'dias', value: 2, target: 3, unit: 'dias'),
      WeeklyGoal(name: 'feita', value: 3, target: 3, unit: 'conquistas'),
    ];
    expect(WeeklyGoal.featured(goals)?.name, 'dias');
    expect(goals.first.missing, 'Faltam 8 km');
  });

  test('week time left counts down to the end of the local week', () {
    final now = DateTime.utc(2026, 10, 4, 18, 22);
    expect(weekTimeLeft('2026-09-28T03:00:00Z', now), '8h 38min restantes');
    expect(weekTimeLeft('2026-09-21T03:00:00Z', now), isNull);
    expect(weekTimeLeft('2026-10-01T03:00:00Z', now), '3d 8h restantes');
  });

  testWidgets('runs screen splits history and weekly challenges into tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final weekStart = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 1))
        .toIso8601String();
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          return http.Response(
            jsonEncode({
              'week_start': weekStart,
              'runs_count': 4,
              'distance_km': 18.5,
              'longest_run_km': 7.2,
              'goals': [
                {
                  'name': 'Correr 10 km nesta semana',
                  'value': 4.5,
                  'target': 10,
                  'unit': 'km',
                },
                {
                  'name': 'Correr em 3 dias nesta semana',
                  'value': 2,
                  'target': 3,
                  'unit': 'dias',
                },
              ],
              'badges': [
                {'name': 'Primeira corrida', 'earned': true},
                {'name': '10 corridas', 'earned': false},
              ],
              'team': null,
            }),
            200,
          );
        }
        if (request.url.path == '/runs') {
          return http.Response(
            jsonEncode([
              {
                'id': 'r1',
                'name': 'Volta no parque',
                'started_at': '2026-10-03T10:00:00Z',
                'distance_m': 5200,
              },
            ]),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson({
        'id': '1',
        'full_name': 'Marina Oliveira',
        'username': 'marina',
        'email': 'marina@example.com',
        'total_score': 0,
        'territories_count': 0,
      });
    addTearDown(state.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const RunsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Volta no parque'), findsOneWidget);
    expect(find.text('18.5 km'), findsOneWidget);

    await tester.tap(find.text('Desafios'));
    await tester.pumpAndSettle();

    expect(find.text('Próxima meta'), findsOneWidget);
    expect(find.text('Correr em 3 dias nesta semana'), findsNWidgets(2));
    expect(find.text('Falta 1 dia'), findsOneWidget);
    expect(find.text('Metas da semana'), findsOneWidget);
    expect(find.text('Primeira corrida'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
