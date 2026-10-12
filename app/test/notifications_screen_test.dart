import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/notifications_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

/// O que `GET /notifications` devolve. Os dias são montados a partir do hoje
/// local do teste: a etiqueta da grupo (`Hoje`, `Ontem`) depende do fuso do
/// aparelho, e um instante fixo em UTC cairia em outro dia.
String _todayAt(int hour, int minute) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).toUtc().toIso8601String();
}

String _yesterdayAt(int hour, int minute) {
  final now = DateTime.now().subtract(const Duration(days: 1));
  return DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).toUtc().toIso8601String();
}

Map<String, dynamic> _note({
  required String id,
  required String message,
  required String type,
  required String createdAt,
  bool read = false,
}) => {
  'id': id,
  'message': message,
  'type': type,
  'is_read': read,
  'created_at': createdAt,
};

/// A caixa do servidor, mais recente primeiro — a mesma ordem do `order_by`
/// da rota. Duas não lidas (hoje), uma de ontem e uma de janeiro, já lidas.
List<Map<String, dynamic>> _inbox() => [
  _note(
    id: 'n1',
    message: 'Você dominou a Praça Seca! +120 pontos.',
    type: 'conquista',
    createdAt: _todayAt(9, 5),
  ),
  _note(
    id: 'n2',
    message: 'Sua equipe alcançou o nível 4!',
    type: 'nivel',
    createdAt: _todayAt(7, 30),
  ),
  _note(
    id: 'n3',
    message: 'Você perdeu o território Mercadão.',
    type: 'perda',
    createdAt: _yesterdayAt(18, 45),
    read: true,
  ),
  _note(
    id: 'n4',
    message: '@bruno aceitou o convite para Rapaduras.',
    type: 'equipe',
    createdAt: '2026-01-08T12:00:00Z',
    read: true,
  ),
];

void main() {
  Future<void> openScreen(
    WidgetTester tester,
    Size size, {
    List<Map<String, dynamic>> Function()? inbox,
    int failures = 0,
    bool patchFails = false,
    Brightness brightness = Brightness.dark,
    void Function(String path, String method)? onRequest,
    Key? screenKey,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // O servidor decide pelo estado guardado, não pelo número da chamada: depois
    // do resgate a mesma notificação volta lida, é o que a tela relê.
    var readIds = <String>{};
    var remainingFailures = failures;

    final api = ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        onRequest?.call(path, request.method);
        if (path == '/notifications') {
          if (remainingFailures > 0) {
            remainingFailures--;
            return http.Response(
              jsonEncode({
                'detail': 'Não foi possível carregar suas notificações.',
              }),
              500,
            );
          }
          final items = [
            for (final n in (inbox ?? _inbox)())
              {
                ...n,
                'is_read': n['is_read'] == true || readIds.contains(n['id']),
              },
          ];
          return http.Response(jsonEncode(items), 200);
        }
        final read = RegExp(r'^/notifications/(.+)/read$').firstMatch(path);
        if (read != null) {
          if (patchFails) {
            return http.Response(
              jsonEncode({'detail': 'Notificação não encontrada.'}),
              404,
            );
          }
          readIds.add(read.group(1)!);
          final item = _inbox().firstWhere((n) => n['id'] == read.group(1)!);
          return http.Response(jsonEncode({...item, 'is_read': true}), 200);
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
          theme: buildRunoverTheme(brightness: brightness),
          home: NotificationsScreen(key: screenKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a caixa vem do servidor, agrupada pelo dia e com a hora certa', (
    tester,
  ) async {
    // O ponto de não lida é tinta e acessibilidade: sem a árvore de semântica
    // montada, `bySemanticsLabel` não enxerga nada.
    final semantics = tester.ensureSemantics();
    await openScreen(tester, const Size(390, 1400));

    // As etiquetas de dia saem do helper compartilhado, em maiúsculas de seção.
    expect(find.text('HOJE'), findsOneWidget);
    expect(find.text('ONTEM'), findsOneWidget);
    expect(find.text('8 JAN'), findsOneWidget);

    expect(
      find.text('Você dominou a Praça Seca! +120 pontos.'),
      findsOneWidget,
    );
    // A hora vem com o minuto em dois dígitos: montada na mão seria `9:5`.
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('9:5'), findsNothing);
    // E o dia não se repete dentro do cartão em formato de número.
    expect(find.textContaining(' às '), findsNothing);

    // Duas não lidas, duas lidas: o ponto marca só a que ainda não foi aberta.
    expect(find.bySemanticsLabel('Não lida'), findsNWidgets(2));

    // Nada de `ListTile` crua: cada aviso é um cartão do kit.
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('tocar numa não lida escreve no servidor e a caixa relê', (
    tester,
  ) async {
    final requested = <String>[];
    final semantics = tester.ensureSemantics();
    await openScreen(
      tester,
      const Size(390, 1400),
      onRequest: (path, method) => requested.add('$method $path'),
    );
    expect(find.bySemanticsLabel('Não lida'), findsNWidgets(2));

    await tester.tap(find.text('Você dominou a Praça Seca! +120 pontos.'));
    await tester.pumpAndSettle();

    expect(requested, contains('PATCH /notifications/n1/read'));
    // Relida: a notificação some do conjunto de não lidas, sem edição local.
    expect(find.bySemanticsLabel('Não lida'), findsOneWidget);
    expect(
      find.text('Você dominou a Praça Seca! +120 pontos.'),
      findsOneWidget,
    );

    // A que já foi lida não tem o que escrever: tocar nela não dispara nada.
    requested.clear();
    await tester.tap(find.text('Você dominou a Praça Seca! +120 pontos.'));
    await tester.pumpAndSettle();
    expect(requested, isEmpty);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('falha ao marcar avisa, e o aviso não some da caixa', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openScreen(tester, const Size(390, 1400), patchFails: true);

    await tester.tap(find.text('Você dominou a Praça Seca! +120 pontos.'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível marcar a notificação como lida.'),
      findsOneWidget,
    );
    // A caixa continua a do servidor: nada se marcou por conta própria.
    expect(find.bySemanticsLabel('Não lida'), findsNWidgets(2));
    // Deixa o aviso sair: o timer de dispensa tem de zerar antes do fim.
    await tester.pumpAndSettle(const Duration(seconds: 6));
    semantics.dispose();
  });

  testWidgets('o botão de atualizar refaz a leitura da caixa', (tester) async {
    final requested = <String>[];
    await openScreen(
      tester,
      const Size(390, 1400),
      onRequest: (path, method) => requested.add('$method $path'),
    );
    expect(requested.where((r) => r == 'GET /notifications'), hasLength(1));

    await tester.tap(find.byTooltip('Atualizar'));
    await tester.pumpAndSettle();
    expect(requested.where((r) => r == 'GET /notifications'), hasLength(2));
    expect(find.text('HOJE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha de leitura vira cartão com botão, não spinner eterno', (
    tester,
  ) async {
    await openScreen(tester, const Size(390, 1400), failures: 1);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Não foi possível carregar suas notificações.'),
      findsOneWidget,
    );
    expect(find.text('TENTAR DE NOVO'), findsOneWidget);

    await tester.tap(find.text('TENTAR DE NOVO'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar suas notificações.'),
      findsNothing,
    );
    expect(find.text('HOJE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caixa vazia diz o que a pessoa pode esperar receber', (
    tester,
  ) async {
    await openScreen(tester, const Size(390, 1400), inbox: () => []);

    expect(find.text('Nenhuma notificação ainda.'), findsOneWidget);
    expect(find.textContaining('avisos da equipe chegam aqui'), findsOneWidget);
    expect(find.text('HOJE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a caixa se lê no tema claro e no escuro, em três larguras', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 740),
        Size(390, 844),
        Size(1280, 800),
      ]) {
        await openScreen(
          tester,
          size,
          brightness: brightness,
          screenKey: ValueKey('$brightness-$size'),
        );
        expect(find.text('HOJE'), findsOneWidget);
        expect(
          find.text('Você dominou a Praça Seca! +120 pontos.'),
          findsOneWidget,
        );
        // O cartão da última linha cabe na tela menor sem estourar a linha.
        expect(
          find.text('@bruno aceitou o convite para Rapaduras.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
