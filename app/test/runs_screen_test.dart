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
  ) async {    SharedPreferences.setMockInitialValues({});
    // Tela alta para montar a aba inteira: o ListView constrói os filhos sob
    // demanda e os tiles do fim somem da árvore em telas curtas.
    tester.view.physicalSize = const Size(390, 2000);
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

    expect(find.text('Desafios do dia'), findsOneWidget);
    expect(
      find.text('Sorteio pessoal de @marina • muda à meia-noite'),
      findsOneWidget,
    );
    expect(find.textContaining('troca em'), findsOneWidget);
    expect(find.text('Próxima meta'), findsOneWidget);
    expect(find.text('Correr em 3 dias nesta semana'), findsNWidgets(2));
    expect(find.text('Falta 1 dia'), findsOneWidget);
    expect(find.text('Metas da semana'), findsOneWidget);
    expect(find.text('Primeira corrida'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openHistory(
    WidgetTester tester,
    Size size, {
    List<Map<String, dynamic>> extraRuns = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          return http.Response(
            jsonEncode({
              'week_start': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'runs_count': 4,
              'distance_km': 18.5,
              'longest_run_km': 7.2,
              'goals': [],
              'badges': [],
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
                'duration_seconds': 1725,
                'pace_seconds_per_km': 330,
              },
              ...extraRuns,
            ]),
            200,
            // Sem o charset explícito o corpo é Latin-1: o travessão de um
            // `claim_error` chegava quebrado na tela.
            headers: {'content-type': 'application/json; charset=utf-8'},
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
  }

  Future<void> expectHistoryCards(WidgetTester tester) async {
    // Resumo consolidado com ícones.
    expect(find.text('Total de Corridas'), findsOneWidget);
    expect(find.text('Distância Total'), findsOneWidget);
    expect(find.text('Maior Corrida'), findsOneWidget);
    expect(find.byIcon(Icons.directions_run), findsWidgets);
    expect(find.byIcon(Icons.route), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    // Cartão horizontal: título, distância, tempo e ritmo com ícones.
    expect(find.text('Volta no parque'), findsOneWidget);
    expect(find.text('5,20 km'), findsOneWidget);
    expect(find.text('28:45'), findsOneWidget);
    expect(find.text('5\'30"/km'), findsOneWidget);
    expect(find.byIcon(Icons.straighten), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.byIcon(Icons.speed), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('history cards fit a small phone', (tester) async {
    await openHistory(tester, const Size(320, 740));
    await expectHistoryCards(tester);
  });

  testWidgets('history cards fit a standard phone', (tester) async {
    await openHistory(tester, const Size(390, 844));
    await expectHistoryCards(tester);
  });

  testWidgets('history cards fit a desktop window', (tester) async {
    await openHistory(tester, const Size(1280, 800));
    await expectHistoryCards(tester);
  });

  testWidgets('the list says why a run did not conquer', (tester) async {
    await openHistory(
      tester,
      const Size(390, 2000),
      extraRuns: [
        {
          'id': 'r2',
          'name': 'Laço da praça',
          'started_at': '2026-10-02T09:00:00Z',
          'distance_m': 1800,
          'claim': {
            'created_new': true,
            'points_awarded': 120,
            'challenge_won': null,
            'territory': {'name': 'Praça Seca'},
          },
        },
        {
          'id': 'r3',
          'name': 'Volta pela metade',
          'started_at': '2026-10-01T09:00:00Z',
          'distance_m': 900,
          'claim_error': 'Percurso não fechado — faltam ~480m.',
        },
      ],
    );

    expect(
      find.text('Conquistado · Praça Seca · +120 pts'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Percurso não fechado'),
      findsOneWidget,
    );
    // A corrida sem tentativa de conquista não ganha linha nenhuma.
    expect(find.byIcon(Icons.terrain), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
