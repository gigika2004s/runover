import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/team_settings_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

const _teamId = 'team-1';
const _teamPath = '/teams/$_teamId';

/// JSON de `TeamDetail` com os padrões de uma equipe de três pessoas, onde
/// `marina` (o perfil do teste) é a dona.
Map<String, dynamic> teamSettingsJson({
  String name = 'RUNOVER',
  String? photoUrl,
  bool owner = true,
  bool admin = true,
  int memberCount = 3,
  List<Map<String, dynamic>>? members,
  String joinMode = 'approval',
  bool listed = true,
  bool notifyRisk = true,
  bool notifyRequests = true,
  String? inviteToken,
  List<Map<String, dynamic>> requests = const [],
}) => {
  'id': _teamId,
  'name': name,
  'photo_url': photoUrl,
  'creator_username': 'marina',
  'member_count': memberCount,
  'members':
      members ??
      [
        {'username': 'marina', 'photo_url': null},
        {'username': 'pedro', 'photo_url': null},
      ],
  'total_score': 320,
  'territories_count': 4,
  'level': 3,
  'level_progress': 0.4,
  'points_to_next_level': 120,
  'zone_capacity': 7,
  'is_owner': owner,
  'is_admin': admin,
  'pending_requests': requests,
  'join_mode': joinMode,
  'listed': listed,
  'notify_risk': notifyRisk,
  'notify_requests': notifyRequests,
  'invite_token': inviteToken,
};

class TeamSettingsCalls {
  final List<String> requests = [];
  Map<String, dynamic>? lastPatch;
  Map<String, dynamic>? lastLeave;

  bool called(String verbAndPath) => requests.contains(verbAndPath);
}

/// Abre a tela de configurações contra um `MockClient` que registra as chamadas
/// e devolve a equipe informada (com o link de convite renovado quando o
/// servidor é chamado para regenerar).
///
/// `failOn` faz falhar com 409 a chamada cujo `MÉTODO /caminho` contém o texto.
/// `routed` abre a tela por dentro de um `Navigator`, como o painel faz: só
/// assim dá para ver se uma ação que falhou fechou a tela na mesma.
Future<TeamSettingsCalls> openTeamSettings(
  WidgetTester tester,
  Map<String, dynamic> teamJson, {
  String? failOn,
  bool routed = false,
}) async {
  tester.view.physicalSize = const Size(560, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final calls = TeamSettingsCalls();
  final api = ApiClient(
    client: MockClient((request) async {
      final method = request.method;
      final path = request.url.path;
      calls.requests.add('$method $path');
      if (failOn != null && '$method $path'.contains(failOn)) {
        return http.Response(jsonEncode({'detail': 'Ação indisponível.'}), 409);
      }
      if (method == 'PATCH' && path == _teamPath) {
        calls.lastPatch = jsonDecode(request.body) as Map<String, dynamic>;
        final saved = Map<String, dynamic>.from(teamJson);
        final body = calls.lastPatch!;
        if (body['name'] != null) saved['name'] = body['name'];
        if (body['photo_url'] != null) saved['photo_url'] = body['photo_url'];
        return http.Response(jsonEncode(saved), 200);
      }
      if (path.endsWith('/invite/regenerate')) {
        return http.Response(
          jsonEncode({...teamJson, 'invite_token': 'novo-token'}),
          200,
        );
      }
      if (path.contains('/requests/')) {
        return http.Response(
          jsonEncode({...teamJson, 'pending_requests': <String>[]}),
          200,
        );
      }
      if (method == 'POST' && path == '/teams/leave') {
        calls.lastLeave = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 204);
      }
      if (method == 'DELETE' && path == _teamPath) {
        return http.Response('', 204);
      }
      return http.Response('{}', 200);
    }),
  );
  addTearDown(api.close);

  final state = AppState(api: api)
    ..profile = UserProfile.fromJson(profileData);
  addTearDown(state.dispose);

  final screen = TeamSettingsScreen(
    team: TeamDetail.fromJson(teamJson),
    onChanged: () {},
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: buildRunoverTheme(),
        home: routed
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => screen),
                      ),
                      child: const Text('Abrir ajustes'),
                    ),
                  ),
                ),
              )
            : screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (routed) {
    await tester.tap(find.text('Abrir ajustes'));
    await tester.pumpAndSettle();
  }
  return calls;
}

/// A tela é uma `ListView`: itens de baixo só entram na árvore depois de rolar.
/// A chave pega a lista da tela, não a faixa horizontal de avatares.
final _settingsList = find.byKey(const Key('team-settings-list'));

Future<void> scrollTo(WidgetTester tester, String text) async {
  final target = find.text(text);
  for (var i = 0; i < 16 && target.evaluate().isEmpty; i++) {
    await tester.drag(_settingsList, const Offset(0, -420));
    await tester.pump();
  }
}

/// Toca um controle da lista levando a linha para o meio da dobra: rolada só
/// até aparecer, a linha pode ficar na beirada de baixo e o toque não alcança.
Future<void> tapRow(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 24 && finder.evaluate().isEmpty; i++) {
    await tester.drag(_settingsList, const Offset(0, -240));
    await tester.pump();
  }
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  for (var i = 0; i < 8; i++) {
    // Arrastar move o conteúdo junto com o dedo: para a linha descer do topo
    // para o meio, o deslocamento é o próprio (meio - posição atual).
    final delta = (height / 2 - tester.getTopLeft(finder).dy).clamp(
      -300.0,
      300.0,
    );
    if (delta.abs() < 16) break;
    await tester.drag(_settingsList, Offset(0, delta));
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('quem edita vê todas as seções de ajuste', (tester) async {
    await openTeamSettings(tester, teamSettingsJson(inviteToken: 'tok'));
    for (final section in [
      'PERFIL DA EQUIPE',
      'QUEM PODE ENTRAR',
      'CONVITES',
      'PEDIDOS DE ENTRADA',
      'AVISOS DA EQUIPE',
      'ZONA DE RISCO',
    ]) {
      await scrollTo(tester, section);
      expect(find.text(section), findsOneWidget, reason: section);
    }
  });

  testWidgets('membro sem cargo não recebe controle de edição', (tester) async {
    await openTeamSettings(
      tester,
      teamSettingsJson(owner: false, admin: false, memberCount: 3),
    );
    expect(find.text('Você é membro: estes dados são da equipe e você pode sair.'), findsOneWidget);
    await scrollTo(tester, 'QUEM PODE ENTRAR');
    // O membro lê o modo escolhido, sem poder escolher.
    expect(find.text('Por aprovação'), findsOneWidget);
    expect(find.text('Aberta'), findsNothing);
    for (final hidden in [
      'CONVITES',
      'PEDIDOS DE ENTRADA',
      'AVISOS DA EQUIPE',
      'Foto da equipe',
      'Salvar alterações',
      'Dissolver',
    ]) {
      await scrollTo(tester, hidden);
      expect(find.text(hidden), findsNothing, reason: hidden);
    }
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('salvar envia nome, entrada, listagem e avisos', (tester) async {
    final calls = await openTeamSettings(tester, teamSettingsJson());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da equipe'),
      'RUNOVER 2',
    );
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(calls.lastPatch, {
      'name': 'RUNOVER 2',
      'join_mode': 'approval',
      'listed': true,
      'notify_risk': true,
      'notify_requests': true,
    });
    expect(find.text('Alterações salvas'), findsOneWidget);
  });

  testWidgets('nome de uma letra não sai do aparelho', (tester) async {
    final calls = await openTeamSettings(tester, teamSettingsJson());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da equipe'),
      'A',
    );
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('O nome precisa de pelo menos 2 letras'), findsOneWidget);
    expect(calls.called('PATCH $_teamPath'), isFalse);
  });

  testWidgets('trocar o modo de entrada marca como alterado', (tester) async {
    await openTeamSettings(tester, teamSettingsJson());
    await tester.tap(find.text('Aberta'));
    await tester.pump();
    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancelar'),
    );
    expect(cancel.onPressed, isNotNull);
  });

  testWidgets('gerar link chama o servidor e mostra o link novo', (tester) async {
    final calls = await openTeamSettings(tester, teamSettingsJson());
    await scrollTo(tester, 'Gere um link para convidar');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Gerar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar'));
    await tester.pumpAndSettle();
    expect(calls.called('POST $_teamPath/invite/regenerate'), isTrue);
    expect(find.text('/teams/join/novo-token'), findsOneWidget);
  });

  testWidgets('aceitar pedido decide no servidor e some da lista', (tester) async {
    final calls = await openTeamSettings(
      tester,
      teamSettingsJson(
        requests: [
          {
            'id': 'req-1',
            'username': 'zoe',
            'photo_url': null,
            'created_at': '2026-10-10T12:00:00Z',
          },
        ],
      ),
    );
    await scrollTo(tester, '@zoe');
    expect(find.text('@zoe'), findsOneWidget);
    await tapRow(tester, find.byTooltip('Aceitar pedido'));
    expect(calls.called('POST $_teamPath/requests/req-1/approve'), isTrue);
    expect(find.text('@zoe'), findsNothing);
  });

  testWidgets('dissolver é do dono e pede o nome digitado', (tester) async {
    final calls = await openTeamSettings(tester, teamSettingsJson());
    await scrollTo(tester, 'Dissolver equipe');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Dissolver'));
    expect(find.text('Dissolver equipe?'), findsOneWidget);
    // Sem o nome, nada de confirmar.
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Dissolver')).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField).last, 'RUNOVER');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Dissolver'));
    await tester.pumpAndSettle();
    expect(calls.called('DELETE $_teamPath'), isTrue);
  });

  testWidgets('link atual continua quando a regeneração falha', (
    tester,
  ) async {
    final calls = await openTeamSettings(
      tester,
      teamSettingsJson(inviteToken: 'tok'),
      failOn: 'invite/regenerate',
    );
    await scrollTo(tester, 'Gere um link para convidar');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Gerar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar'));
    await tester.pumpAndSettle();
    expect(calls.called('POST $_teamPath/invite/regenerate'), isTrue);
    expect(find.text('Ação indisponível.'), findsOneWidget);
    // O servidor não gerou nada: o link que já existia não pode sumir da tela.
    expect(find.text('/teams/join/tok'), findsOneWidget);
  });

  testWidgets('pedido que o servidor recusa continua na lista', (
    tester,
  ) async {
    final calls = await openTeamSettings(
      tester,
      teamSettingsJson(
        requests: [
          {
            'id': 'req-1',
            'username': 'zoe',
            'photo_url': null,
            'created_at': '2026-10-10T12:00:00Z',
          },
        ],
      ),
      failOn: '/requests/',
    );
    await scrollTo(tester, '@zoe');
    await tapRow(tester, find.byTooltip('Recusar pedido'));
    expect(calls.called('POST $_teamPath/requests/req-1/reject'), isTrue);
    expect(find.text('Ação indisponível.'), findsOneWidget);
    // A decisão não aconteceu: esconder o pedido faria a tela prometer algo que
    // o servidor ainda tem pendurado.
    expect(find.text('@zoe'), findsOneWidget);
  });

  testWidgets('dissolver de verdade fecha a tela de ajustes', (
    tester,
  ) async {
    final calls = await openTeamSettings(
      tester,
      teamSettingsJson(),
      routed: true,
    );
    await scrollTo(tester, 'Dissolver equipe');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Dissolver'));
    await tester.enterText(find.byType(TextField).last, 'RUNOVER');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Dissolver'));
    await tester.pumpAndSettle();
    expect(calls.called('DELETE $_teamPath'), isTrue);
    expect(find.widgetWithText(AppBar, 'Configurações'), findsNothing);
    expect(find.text('Abrir ajustes'), findsOneWidget);
  });

  testWidgets('dissolver recusado deixa a tela de ajustes aberta', (
    tester,
  ) async {
    final calls = await openTeamSettings(
      tester,
      teamSettingsJson(),
      failOn: 'DELETE $_teamPath',
      routed: true,
    );
    await scrollTo(tester, 'Dissolver equipe');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Dissolver'));
    await tester.enterText(find.byType(TextField).last, 'RUNOVER');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Dissolver'));
    await tester.pumpAndSettle();
    expect(calls.called('DELETE $_teamPath'), isTrue);
    expect(find.text('Ação indisponível.'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Configurações'), findsOneWidget);
  });

  testWidgets('admin sem a posse não dissolve a equipe', (tester) async {
    await openTeamSettings(
      tester,
      teamSettingsJson(owner: false, admin: true, memberCount: 3),
    );
    await scrollTo(tester, 'ZONA DE RISCO');
    expect(find.text('Dissolver'), findsNothing);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('dono que sai escolhe o sucessor', (tester) async {
    final calls = await openTeamSettings(tester, teamSettingsJson());
    await scrollTo(tester, 'ZONA DE RISCO');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Sair'));
    expect(find.text('Passar a posse ou dissolver?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Transferir e sair'));
    await tester.pumpAndSettle();
    expect(calls.lastLeave?['successor_username'], 'pedro');
  });

  testWidgets('admin que sai só confirma', (tester) async {
    final calls = await openTeamSettings(
      tester,
      teamSettingsJson(owner: false, admin: true),
    );
    await scrollTo(tester, 'ZONA DE RISCO');
    await tapRow(tester, find.widgetWithText(OutlinedButton, 'Sair'));
    expect(find.text('Sair da equipe?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await tester.pumpAndSettle();
    expect(calls.lastLeave, isNotNull);
    expect(calls.lastLeave!.containsKey('successor_username'), isFalse);
  });
}
