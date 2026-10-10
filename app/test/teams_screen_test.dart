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
import 'package:runover_app/widgets/cosmetics.dart';

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
  'territories_count': 3,
  // As conquistas reais, na ordem: a primeira acende a célula central.
  'territories': [
    {
      'name': 'Praça Central',
      'points': 30,
      'conquered_at': '2026-09-28T15:40:00',
    },
    {
      'name': 'Parque do Bairro',
      'points': 10,
      'conquered_at': '2026-10-02T08:10:00',
    },
    {
      'name': 'Orla',
      'points': 20,
      'conquered_at': '2026-10-06T19:05:00',
    },
  ],
  'level': 1,
  'level_progress': 0.4,
  'points_to_next_level': 90,
};

void main() {
  Future<void> open(
    WidgetTester tester,
    Size size, {
    Map<String, Object?>? team,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(team ?? teamData), 200);
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

  /// As células vazias da base. O ícone "+" também aparece em outros botões
  /// do painel, então o finder é restrito ao card da base.
  Finder freeSlots(WidgetTester tester) => find.descendant(
    of: find.ancestor(
      of: find.text('Base da equipe'),
      matching: find.byType(Card),
    ),
    matching: find.byIcon(Icons.add),
  );

  Future<void> expectTeamLayout(WidgetTester tester) async {
    // Cabeçalho com ícone + título.
    expect(find.text('Equipe'), findsOneWidget);
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    // Avatar, nome e criador.
    expect(find.text('Lobos do Asfalto'), findsOneWidget);
    expect(find.text('Criada por @misaia'), findsOneWidget);
    // Selo de nível uma única vez: o painel mostra o progresso no próprio card.
    expect(find.text('Nv 1'), findsOneWidget);
    // Card de progresso da equipe.
    expect(find.text('Progresso da equipe'), findsOneWidget);
    expect(find.text('320 / 410 pts'), findsOneWidget);
    expect(find.text('Faltam 90 pts para o nível 2'), findsOneWidget);
    expect(find.text('Próximo nível'), findsOneWidget);
    expect(
      find.text('O nível 2 libera mais zonas na base'),
      findsOneWidget,
    );
    // Cartões de estatística com ícones e a base hexagonal.
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.text('Pontos'), findsOneWidget);
    expect(find.text('Zonas conquistadas'), findsOneWidget);
    expect(find.text('3 / 7'), findsOneWidget);
    expect(find.text('Base da equipe'), findsOneWidget);
    // Uma célula acesa por conquista real; o resto da base está livre.
    expect(find.byIcon(Icons.push_pin), findsNWidgets(3));
    expect(freeSlots(tester), findsNWidgets(4));
    expect(
      find.text('Toque em uma zona para ver o território que a acende'),
      findsOneWidget,
    );
    // Membros com contagem e destaque do criador.
    expect(find.text('Membros (2)'), findsOneWidget);
    expect(find.text('@misaia'), findsOneWidget);
    expect(find.text('@ana'), findsOneWidget);
    expect(find.text('Criador'), findsOneWidget);
    expect(find.text('Convidar amigos'), findsOneWidget);
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

  testWidgets('zona acesa mostra o território real por trás dela',
      (tester) async {
    await open(tester, const Size(390, 844));
    await tester.tap(find.byIcon(Icons.push_pin).first);
    await tester.pumpAndSettle();

    expect(find.text('Zona 1'), findsOneWidget);
    expect(find.text('Praça Central'), findsOneWidget);
    expect(find.text('30 pts · conquistado em 28/09/2026'), findsOneWidget);
    expect(
      find.text(
        'A célula pertence enquanto a posse for da equipe: se outro '
        'corredor fechar o laço por cima, o território muda de dono e '
        'a zona se apaga.',
      ),
      findsOneWidget,
    );
    // O id interno da equipe não aparece em lugar nenhum.
    expect(find.textContaining('team-test'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zona livre explica como acendê-la', (tester) async {
    await open(tester, const Size(390, 844));
    await tester.tap(freeSlots(tester).first);
    await tester.pumpAndSettle();

    expect(find.text('Zona 4'), findsOneWidget);
    expect(find.text('Livre — nada ocupa esta célula ainda.'), findsOneWidget);
    expect(
      find.textContaining('feche um laço com o trajeto gravado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('equipe sem conquista deixa a base toda livre', (tester) async {
    await open(tester, const Size(390, 844), team: {
      ...teamData,
      'territories_count': 0,
      'territories': [],
    });

    expect(find.text('0 / 7'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsNothing);
    expect(freeSlots(tester), findsNWidgets(7));
    expect(
      find.text('Zona 1: conquiste um território no mapa para acendê-la'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('teamCardAsset é estável e usa a galeria', () {
    final first = teamCardAsset('team-1');
    expect(first, teamCardAsset('team-1'));
    expect(presetAvatars.map((p) => p.asset), contains(first));
  });

  testWidgets('lista mostra cards e pedido fica pendente', (tester) async {
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
    expect(find.text('Criada por @misaia'), findsOneWidget);
    expect(find.text('2 membros'), findsOneWidget);
    expect(find.byKey(const Key('team-join-t1')), findsOneWidget);
    expect(find.text('Solicitar entrada'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('team-join-t1')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Solicitar entrada na equipe Lobos do Asfalto'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('team-join-t1')));
    await tester.pumpAndSettle();
    expect(joins, 1);
    expect(find.text('Aguardando aprovação'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Pedido pendente em Lobos do Asfalto'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('descoberta filtra por busca e por equipes novas', (
    tester,
  ) async {    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now().toUtc();
    String iso(DateTime d) => d.toIso8601String();
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/teams') {
          return http.Response(
            jsonEncode([
              {
                'id': 'nova',
                'name': 'Lobos Novos',
                'creator_username': 'misaia',
                'member_count': 2,
                'territories_count': 0,
                'created_at': iso(now),
              },
              {
                'id': 'velha',
                'name': 'Velha Guarda',
                'creator_username': 'ana',
                'member_count': 5,
                'territories_count': 12,
                'created_at': iso(now.subtract(const Duration(days: 30))),
              },
            ]),
            200,
          );
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

    expect(find.text('Lobos Novos'), findsOneWidget);
    expect(find.text('Velha Guarda'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('Seja o primeiro'), findsOneWidget);
    expect(find.text('Recrutando'), findsNothing);

    await tester.enterText(find.byType(TextField), 'velha');
    await tester.pumpAndSettle();
    expect(find.text('Velha Guarda'), findsOneWidget);
    expect(find.text('Lobos Novos'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novas'));
    await tester.pumpAndSettle();
    expect(find.text('Lobos Novos'), findsOneWidget);
    expect(find.text('Velha Guarda'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('descoberta acompanha o brilho do app', (tester) async {
    Future<Color?> nameColor(Brightness brightness) async {
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
                  'territories_count': 3,
                  'created_at': DateTime.now()
                      .toUtc()
                      .toIso8601String(),
                },
              ]),
              200,
            );
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
            theme: buildRunoverTheme(brightness: brightness),
            home: const TeamsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return tester.widget<Text>(find.text('Lobos do Asfalto')).style?.color;
    }

    final light = await nameColor(Brightness.light);
    final dark = await nameColor(Brightness.dark);
    expect(light, isNotNull);
    expect(dark, isNotNull);
    expect(light, isNot(dark));
    expect(
      ThemeData.estimateBrightnessForColor(light!),
      Brightness.dark,
    );
    expect(ThemeData.estimateBrightnessForColor(dark!), Brightness.light);
  });

  testWidgets('team list photo falls back when the network image fails', (
    tester,
  ) async {    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/teams') {
          return http.Response(
            jsonEncode([
              {
                'id': 'broken-photo',
                'name': 'Equipe com foto indisponÃ­vel',
                'creator_username': 'misaia',
                'member_count': 2,
                'photo_url': 'https://example.invalid/team.png',
              },
            ]),
            200,
          );
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

    // A URL de rede é irresolúvel: o NetworkImage falha de verdade e a
    // letra inicial aparece no lugar (mesma lógica dos avatares).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FramedAvatar), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin aprova pedido na tela da equipe', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var approvals = 0;
    Map<String, dynamic> detail = {
      ...teamData,
      'is_owner': true,
      'is_admin': true,
      'pending_requests': [
        {
          'id': 'req-1',
          'username': 'ana',
          'photo_url': null,
          'created_at': '2026-10-01T00:00:00Z',
        },
      ],
    };
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(detail), 200);
        }
        if (request.url.path == '/teams/team-test/requests/req-1/approve') {
          approvals++;
          detail = {...detail, 'pending_requests': []};
          return http.Response(jsonEncode(detail), 200);
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

    await tester.tap(find.byTooltip('Configurações da equipe'));
    await tester.pumpAndSettle();
    expect(find.text('Convites pendentes (1)'), findsOneWidget);
    expect(find.text('Quer entrar na equipe'), findsOneWidget);
    await tester.tap(find.byTooltip('Aceitar pedido'));
    await tester.pumpAndSettle();
    expect(approvals, 1);
    expect(find.text('Convites pendentes (1)'), findsNothing);
    expect(find.text('Nenhum pedido aguardando.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer da equipe edita foto, nome e dissolve', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var patches = 0;
    var deletes = 0;
    Map<String, dynamic> detail = {
      ...teamData,
      'is_owner': true,
      'is_admin': true,
      'pending_requests': [],
    };
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(detail), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/teams/team-test') {
          patches++;
          detail = {...detail, 'name': 'Novo Nome'};
          return http.Response(jsonEncode(detail), 200);
        }
        if (request.method == 'DELETE' &&
            request.url.path == '/teams/team-test') {
          deletes++;
          return http.Response('', 204);
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

    await tester.tap(find.byTooltip('Configurações da equipe'));
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Convites pendentes (0)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('team-photo-Corredor')));
    await tester.pumpAndSettle();
    expect(patches, 1);

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Novo Nome');
    await tester.tap(find.text('Salvar nome'));
    await tester.pumpAndSettle();
    expect(patches, 2);

    expect(find.text('Dissolver equipe'), findsOneWidget);
    await tester.tap(find.text('Dissolver equipe'));
    await tester.pumpAndSettle();
    expect(find.text('Dissolver equipe?'), findsOneWidget);
    await tester.tap(find.text('Dissolver'));
    await tester.pumpAndSettle();
    expect(deletes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foto salva da equipe aparece no cabeçalho', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const dataUri =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRUlErkJggg==';
    final detail = {
      ...teamData,
      'photo_url': dataUri,
      'is_owner': true,
      'is_admin': true,
      'pending_requests': [],
    };
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(detail), 200);
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

    final withPhoto = tester.widgetList<CircleAvatar>(
      find.byWidgetPredicate(
        (w) => w is CircleAvatar && w.foregroundImage is MemoryImage,
      ),
    );
    expect(withPhoto, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  Future<Map<String, dynamic>?> openOwnerLeave(
    WidgetTester tester, {
    required List calls,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(
            jsonEncode({
              ...teamData,
              'is_owner': true,
              'is_admin': true,
              'pending_requests': [],
            }),
            200,
          );
        }
        if (request.url.path == '/teams/leave') {
          calls.add(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          return http.Response('', 204);
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
    await tester.scrollUntilVisible(
      find.text('Sair da equipe'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da equipe'));
    await tester.pumpAndSettle();
    expect(
      find.text('Passar a posse ou dissolver?'),
      findsOneWidget,
    );
    return null;
  }

  testWidgets('dono transfere a posse ao sair', (tester) async {
    final calls = [];
    await openOwnerLeave(tester, calls: calls);
    await tester.tap(find.text('Transferir e sair'));
    await tester.pumpAndSettle();
    expect(calls, [
      {'successor_username': 'misaia'},
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dono dissolve a equipe ao sair', (tester) async {
    final calls = [];
    await openOwnerLeave(tester, calls: calls);
    await tester.tap(find.text('Dissolver a equipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dissolver e sair'));
    await tester.pumpAndSettle();
    expect(calls, [
      {'dissolve': true},
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('membro vê outras equipes mas entra só após sair', (
    tester,
  ) async {    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response(jsonEncode(teamData), 200);
        }
        if (request.url.path == '/teams') {
          return http.Response(
            jsonEncode([
              {
                'id': 'team-b',
                'name': 'Raposas Velozes',
                'photo_url': null,
                'creator_username': 'ana',
                'member_count': 5,
                'territories_count': 3,
              },
            ]),
            200,
          );
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

    await tester.scrollUntilVisible(
      find.text('Ver outras equipes'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    // O painel cresceu: sem trazer o botão para a viewport o toque cai
    // abaixo da dobra e a tela de descoberta nunca abre.
    await tester.ensureVisible(find.text('Ver outras equipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver outras equipes'));
    await tester.pumpAndSettle();
    expect(find.text('Outras equipes'), findsOneWidget);
    expect(
      find.text(
        'Você já está em uma equipe. Para participar de outra, '
        'saia da atual primeiro.',
      ),
      findsOneWidget,
    );
    expect(find.text('Raposas Velozes'), findsOneWidget);

    await tester.tap(find.text('Solicitar entrada'));
    await tester.pumpAndSettle();
    expect(
      find.text('Saia da sua equipe atual para participar de outra.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards da lista mostram moldura e nome da loja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/teams') {
          return http.Response(
            jsonEncode([
              {
                ...teamData,
                'id': 'team-vit',
                'equipped_frame': 'frame_bronze',
                'equipped_name_style': 'name_ouro',
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/shop/catalog') {
          return http.Response(
            jsonEncode([
              {
                'id': 'frame_bronze',
                'category': 'frame',
                'name': 'Moldura bronze',
                'price': 100,
                'payload': {
                  'colors': ['#CD7F32'],
                  'animated': false,
                },
              },
              {
                'id': 'name_ouro',
                'category': 'name_style',
                'name': 'Nome ouro',
                'price': 400,
                'payload': {
                  'colors': ['#FFC93C'],
                  'glow': true,
                  'animated': false,
                },
              },
            ]),
            200,
          );
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
    expect(
      tester.widget<Text>(find.text('Lobos do Asfalto')).style?.color,
      const Color(0xFFFFC93C),
    );
    final framed = tester.widgetList<FramedAvatar>(
      find.byType(FramedAvatar),
    );
    expect(framed.any((f) => f.frame?.id == 'frame_bronze'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
