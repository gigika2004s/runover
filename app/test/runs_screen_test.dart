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

/// O sorteio do dia não mora mais no aparelho: a tela desenha o que
/// `GET /runs/challenges` devolve. Este é o payload do servidor usado nos
/// testes de widget.
Map<String, dynamic> _challengesPayload({bool done = false, bool claimed = false}) =>
    {
      'day': '2026-10-12',
      'challenges': [
        {
          'id': 'km-3',
          'title': 'Três quilômetros',
          'detail': 'Curta distância para manter o hábito',
          'unit': 'km',
          'target': 3,
          'rarity': 'comum',
          'kind': 'distance',
          'value': done ? 3.4 : 0,
          'done': done,
          'points': 20,
          'coins': 0,
          'claimed': claimed,
        },
        {
          'id': 'min-20',
          'title': 'Vinte minutos em movimento',
          'detail': 'No seu ritmo, sem pressa',
          'unit': 'min',
          'target': 20,
          'rarity': 'raro',
          'kind': 'duration',
          'value': 12,
          'done': false,
          'points': 40,
          'coins': 30,
          'claimed': false,
        },
      ],
    };

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

  test('the draw rolls over at local midnight', () {
    expect(timeUntilMidnight(DateTime(2026, 10, 12, 17, 36)), '6h 24min');
    expect(timeUntilMidnight(DateTime(2026, 10, 12, 23, 40)), '20min');
  });

  Future<void> openScreen(
    WidgetTester tester,
    Size size, {
    List<Map<String, dynamic>> runs = const [],
    Map<String, dynamic> progress = const {},
    Map<String, dynamic> Function(String method)? challengesFor,
    void Function(String path, String method)? onRequest,
    // Cada abertura num mesmo teste precisa de chave própria: sem ela o
    // `pumpWidget` reaproveita o State, a aba escolhida e a carga anterior.
    Key? screenKey,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // O servidor devolve o dia inteiro no GET e de novo depois do resgate, então
    // o payload depende do método. Sem `challengesFor`, o desafio é cumprido e
    // pago na hora do resgate.
    final payloadFor =
        challengesFor ??
        (method) => method == 'POST'
            ? _challengesPayload(done: true, claimed: true)
            : _challengesPayload();

    final api = ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        onRequest?.call(path, request.method);
        if (path == '/runs/progress') {
          return http.Response(
            jsonEncode({
              'week_start': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'runs_count': 4,
              'distance_km': 18.5,
              'longest_run_km': 7.2,
              'daily_bonus': 20,
              'daily_bonus_pending': true,
              'goals': [
                {
                  'name': 'Correr 10 km nesta semana',
                  'value': 3.4,
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
              ...progress,
            }),
            200,
          );
        }
        if (path == '/runs') {
          return http.Response(
            jsonEncode(runs),
            200,
            // Sem o charset explícito o corpo é Latin-1: o travessão de um
            // `claim_error` chegava quebrado na tela.
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (path == '/runs/challenges') {
          return http.Response(jsonEncode(payloadFor('GET')), 200);
        }
        if (path == '/runs/challenges/claim') {
          return http.Response(jsonEncode(payloadFor('POST')), 200);
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
          home: RunsScreen(key: screenKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openChallengesTab(WidgetTester tester) async {
    await tester.tap(find.text('DESAFIOS'));
    await tester.pumpAndSettle();
  }

  testWidgets('history shows the numbers, the mode chips and the run rows', (
    tester,
  ) async {
    await openScreen(
      tester,
      const Size(390, 2400),
      runs: [
        {
          'id': 'r1',
          'name': 'Volta no parque',
          'started_at': '2026-10-03T10:00:00Z',
          'distance_m': 5200,
          'duration_seconds': 1725,
          'pace_seconds_per_km': 330,
        },
        {
          'id': 'r2',
          'name': 'Laço da praça',
          // O instante atual garante o rótulo "Hoje" em qualquer fuso.
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'distance_m': 1800,
          'claim': {
            'created_new': true,
            'points_awarded': 120,
            'challenge': null,
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

    // Resumo do servidor em número pt-BR.
    expect(find.text('4'), findsOneWidget);
    expect(find.text('18,5 km'), findsWidgets);
    expect(find.text('7,2 km'), findsWidgets);
    // 'CORRIDAS' é o título da barra e o selo do primeiro cartão.
    expect(find.text('CORRIDAS'), findsNWidgets(2));
    expect(find.text('DISTÂNCIA TOTAL'), findsOneWidget);
    expect(find.text('MAIOR CORRIDA'), findsOneWidget);

    // Filtro derivado do que a corrida registrou.
    expect(find.text('Todos os modos'), findsOneWidget);
    expect(find.text('Dominação'), findsOneWidget);
    expect(find.text('Desafio'), findsOneWidget);

    expect(find.text('5,2 km'), findsOneWidget);
    expect(find.text('28:45 · ritmo 5\'30"/km'), findsOneWidget);
    expect(find.text('3 OUT · CORRIDA'), findsOneWidget);
    // A corrida com conquista mostra o território e o XP ganho.
    expect(find.text('HOJE · DOMINAÇÃO'), findsOneWidget);
    expect(find.text('+1 território'), findsOneWidget);
    expect(find.text('+120 XP'), findsOneWidget);
    // O motivo de não ter conquistado continua na linha da lista.
    expect(find.textContaining('Percurso não fechado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mode chip filters the list', (tester) async {
    await openScreen(
      tester,
      const Size(390, 2400),
      runs: [
        {
          'id': 'r1',
          'name': 'Volta no parque',
          'started_at': '2026-10-03T10:00:00Z',
          'distance_m': 5200,
        },
        {
          'id': 'r2',
          'name': 'Retomada marcada',
          'started_at': '2026-10-02T10:00:00Z',
          'distance_m': 2400,
          'claim': {
            'points_awarded': 90,
            'challenge': 'pace',
            'challenge_won': true,
            'territory': {'name': 'Praça Seca'},
          },
        },
      ],
    );

    expect(find.text('2,4 km'), findsOneWidget);
    await tester.tap(find.text('Desafio'));
    await tester.pumpAndSettle();

    // Só a corrida com desafio vencido permanece; o chip continua na tela.
    expect(find.textContaining('· DESAFIO'), findsOneWidget);
    expect(find.text('2,4 km'), findsOneWidget);
    expect(find.text('5,2 km'), findsNothing);
    expect(find.text('Dominação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the empty history offers the modes and the real daily bonus', (
    tester,
  ) async {
    await openScreen(tester, const Size(390, 2600), runs: []);

    expect(find.text('Nenhuma corrida ainda'), findsOneWidget);
    expect(
      find.textContaining('mesmo sem conquistar um território'),
      findsOneWidget,
    );
    // Os mesmos cartões de modo da home, com entrada real.
    expect(find.text('DOMINAÇÃO'), findsOneWidget);
    expect(find.text('DESAFIO'), findsOneWidget);
    expect(find.text('PIT STOP'), findsOneWidget);
    expect(find.text('JOGAR'), findsNWidgets(2));
    expect(find.text('ENTRAR'), findsOneWidget);
    // O bônus é o número do servidor, não o XP do mock.
    expect(find.textContaining('Bônus do dia: +20 dracmas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the daily challenges come from the server and pay on claim', (
    tester,
  ) async {
    final requested = <String>[];
    await openScreen(
      tester,
      const Size(390, 2600),
      onRequest: (path, method) => requested.add('$method $path'),
    );
    expect(requested, contains('GET /runs/challenges'));

    await openChallengesTab(tester);
    expect(find.text('DESAFIOS DO DIA'), findsOneWidget);
    expect(
      find.text('Sorteio pessoal de @marina · muda à meia-noite'),
      findsOneWidget,
    );
    expect(find.textContaining('troca em'), findsOneWidget);
    expect(find.text('Três quilômetros'), findsOneWidget);
    expect(find.text('COMUM'), findsOneWidget);
    expect(find.text('RARO'), findsOneWidget);
    expect(find.text('+40 XP'), findsOneWidget);
    expect(find.text('12 / 20 min'), findsOneWidget);
    expect(find.text('RESGATAR'), findsNothing);

    // A meta em aberto mais próxima vem do /progress e paga o resgate. As
    // outras metas seguem como linhas próprias, então cada nome aparece uma vez.
    expect(find.text('Próxima meta'), findsOneWidget);
    expect(find.text('Correr em 3 dias nesta semana'), findsOneWidget);
    expect(find.text('Correr 10 km nesta semana'), findsOneWidget);
    expect(find.text('METAS DA SEMANA'), findsOneWidget);
    expect(find.text('Falta 1 dia'), findsOneWidget);
  });

  testWidgets('a finished challenge pays through the server and locks', (
    tester,
  ) async {
    final requested = <String>[];
    // O desafio já nasce cumprido; depois do POST o servidor o devolve
    // resgatado — é o que a tela relê ao recarregar o dia.
    var claimed = false;
    await openScreen(
      tester,
      const Size(390, 2600),
      challengesFor: (method) {
        if (method == 'POST') claimed = true;
        return _challengesPayload(done: true, claimed: claimed);
      },
      onRequest: (path, method) => requested.add('$method $path'),
    );
    await openChallengesTab(tester);

    // O desafio cumprido vira botão; o outro segue mostrando a recompensa.
    expect(find.text('RESGATAR'), findsOneWidget);
    expect(find.text('3,4 / 3 km'), findsOneWidget);
    expect(find.text('+40 XP'), findsOneWidget);

    await tester.tap(find.text('RESGATAR'));
    await tester.pumpAndSettle();

    expect(requested, contains('POST /runs/challenges/claim'));
    expect(find.text('RESGATADO'), findsOneWidget);
    expect(find.textContaining('Três quilômetros resgatado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history fits a small phone, a standard phone and a desktop', (
    tester,
  ) async {
    for (final size in const [Size(320, 740), Size(390, 844), Size(1280, 800)]) {
      await openScreen(
        tester,
        size,
        screenKey: ValueKey(size),
        runs: [
          {
            'id': 'r1',
            'name': 'Volta no parque',
            'started_at': '2026-10-03T10:00:00Z',
            'distance_m': 5200,
            'duration_seconds': 1725,
            'pace_seconds_per_km': 330,
            'claim': {
              'points_awarded': 120,
              'challenge': null,
              'territory': {'name': 'Praça Seca'},
            },
          },
        ],
      );
      expect(find.text('Volta no parque'), findsNothing);
      expect(find.text('5,2 km'), findsOneWidget);
      expect(find.text('+120 XP'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // A aba de desafios percorre as mesmas larguras. Só o topo é montado
      // abaixo da dobra, então a checagem fica no primeiro cartão.
      await tester.tap(find.text('DESAFIOS'));
      await tester.pumpAndSettle();
      expect(find.text('DESAFIOS DO DIA'), findsOneWidget);
      expect(find.text('Três quilômetros'), findsOneWidget);
      expect(find.text('COMUM'), findsOneWidget);
      expect(find.text('0 / 3 km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
