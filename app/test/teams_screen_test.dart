import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/screens/teams_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/services/profile_image_provider.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

const teamData = {
  'id': 'team-test',
  'name': 'Lobos do Asfalto',
  'creator_username': 'misaia',
  'member_count': 2,
  'members': [
    {'username': 'misaia', 'photo_url': null},
    {'username': 'ana', 'photo_url': null},
  ],
  'total_score': 320,
  'territories_count': 15,
  'level': 1,
  'level_progress': 0.4,
  'points_to_next_level': 90,
};

void main() {
  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(teamData), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const TeamsScreen(),
        ),
      ),
    );
    addTearDown(state.dispose);
    await tester.pumpAndSettle();
  }

  Future<void> expectTeamLayout(WidgetTester tester) async {
    // Cabeçalho com ícone + título.
    expect(find.text('Equipe'), findsOneWidget);
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    // Avatar, nome e criador.
    expect(find.text('Lobos do Asfalto'), findsOneWidget);
    expect(find.text('Criada por @misaia'), findsOneWidget);
    // Selo de nível (junto ao nome e no início da barra) + legenda.
    expect(find.text('Nv 1'), findsNWidgets(2));
    expect(
      find.text(
        'Progresso de Nível 1. Total de Pontos: 320. '
        'Faltam 90 pts para o Nível 2.',
      ),
      findsOneWidget,
    );
    // Cartões de estatísticas com ícones.
    expect(find.byIcon(Icons.star), findsWidgets);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.text('Pontos'), findsOneWidget);
    expect(find.text('Territórios'), findsOneWidget);
    // Membros com contagem e destaque do criador.
    expect(find.text('Membros (2)'), findsOneWidget);
    expect(find.text('@misaia'), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    // Ação de sair (rola até o fim da lista em telas pequenas).
    await tester.scrollUntilVisible(
      find.text('Sair da equipe'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sair da equipe'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    // Sem estouros de layout.
    expect(tester.takeException(), isNull);
  }

  testWidgets('team screen fits a small phone', (tester) async {
    await open(tester, const Size(320, 740));
    await expectTeamLayout(tester);
  });

  testWidgets('team screen fits a standard phone', (tester) async {
    await open(tester, const Size(390, 844));
    await expectTeamLayout(tester);
  });

  testWidgets('team screen fits a desktop window', (tester) async {
    await open(tester, const Size(1280, 800));
    await expectTeamLayout(tester);
  });

  test('teamCardAsset é estável e usa a galeria', () {
    final first = teamCardAsset('team-1');
    expect(first, teamCardAsset('team-1'));
    expect(
      presetAvatars.map((p) => p.asset),
      contains(first),
    );
  });

  testWidgets('lista mostra cards com arte e Entrar funciona', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var joins = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/teams') {
          return http.Response(
            jsonEncode([
              {
                'id': 't1',
                'name': 'Lobos do Asfalto',
                'creator_username': 'misaia',
                'member_count': 2,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/teams/t1/join') {
          joins++;
          return http.Response(jsonEncode(teamData), 200);
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
          home: const TeamsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lobos do Asfalto'), findsOneWidget);
    expect(find.text('2 membro(s) · criada por @misaia'), findsOneWidget);
    expect(find.byKey(const Key('team-join-t1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('team-join-t1')));
    await tester.pumpAndSettle();
    expect(joins, 1);
    expect(tester.takeException(), isNull);
  });
}
