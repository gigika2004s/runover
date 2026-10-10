import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/screens/team_settings_screen.dart';

Widget _harness({
  TeamSettings initial = const TeamSettings(name: 'RUNOVER'),
  int memberCount = 3,
  int pendingCount = 0,
  String? inviteLink,
  Future<void> Function(TeamSettings settings)? onSave,
  Future<void> Function()? onLeave,
  Future<void> Function()? onDelete,
  Future<String?> Function()? onRegenerateInvite,
}) {
  return MaterialApp(
    home: TeamSettingsScreen(
      initial: initial,
      memberCount: memberCount,
      pendingCount: pendingCount,
      inviteLink: inviteLink,
      onSave: onSave ?? (_) async {},
      onLeave: onLeave ?? () async {},
      onDelete: onDelete ?? () async {},
      onRegenerateInvite: onRegenerateInvite,
    ),
  );
}

// Os TextFormField têm Scrollable interno, então scrollUntilVisible
// padrão acha vários roláveis; arrasta direto na ListView da tela.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  final target = find.text(text);
  for (var i = 0; i < 12 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
  }
}

void main() {
  testWidgets('mostra todas as seções de ajuste', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    for (final section in [
      'PERFIL DA EQUIPE',
      'QUEM PODE ENTRAR',
      'CONVITES',
      'MEMBROS',
      'AVISOS DA EQUIPE',
      'ZONA DE RISCO',
    ]) {
      await _scrollTo(tester, section);
      expect(find.text(section), findsOneWidget);
    }
  });

  testWidgets('editar o nome habilita salvar e chama onSave', (tester) async {
    TeamSettings? saved;
    await tester.pumpWidget(
      _harness(onSave: (settings) async => saved = settings),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da equipe'),
      'RUNOVER 2',
    );
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pump();
    expect(saved?.name, 'RUNOVER 2');
    expect(find.text('Alterações salvas'), findsOneWidget);
  });

  testWidgets('trocar o modo de entrada marca como alterado', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();
    await tester.tap(find.text('Aberta'));
    await tester.pump();
    // Sem salvar ainda: o botão de cancelar fica habilitado.
    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancelar'),
    );
    expect(cancel.onPressed, isNotNull);
  });

  testWidgets('gerar link chama o callback e exibe o novo link', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _harness(
        onRegenerateInvite: () async {
          calls++;
          return '/teams/join/novo-token';
        },
      ),
    );
    await tester.pump();
    await _scrollTo(tester, 'Gere um link para convidar');
    expect(find.text('Gere um link para convidar'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gerar'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Gerar'));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('/teams/join/novo-token'), findsOneWidget);
  });

  testWidgets('pedidos aparecem com a contagem real', (tester) async {
    await tester.pumpWidget(
      _harness(memberCount: 2, pendingCount: 0),
    );
    await tester.pump();
    await _scrollTo(tester, 'Pedidos de entrada');
    expect(find.text('Nenhum pedido no momento'), findsOneWidget);
  });

  testWidgets('excluir pede o nome e chama onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      _harness(memberCount: 1, onDelete: () async => deleted = true),
    );
    await tester.pump();
    await _scrollTo(tester, 'Excluir equipe');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Excluir'));
    await tester.pump();
    expect(find.text('Excluir equipe?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'RUNOVER');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pump();
    expect(deleted, isTrue);
  });
}
