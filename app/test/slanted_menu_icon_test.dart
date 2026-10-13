import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/slanted_menu_icon.dart';

void main() {
  Future<void> pumpIcon(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRunoverTheme(brightness: brightness),
        home: const Scaffold(
          body: IconButton(
            tooltip: 'Menu',
            icon: SlantedMenuIcon(),
            onPressed: null,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('desenha nos dois temas sem excecao', (tester) async {
    await pumpIcon(tester, Brightness.light);
    expect(find.byKey(const Key('slanted-menu-icon')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpIcon(tester, Brightness.dark);
    expect(find.byKey(const Key('slanted-menu-icon')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpButton(WidgetTester tester, {VoidCallback? onPressed}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRunoverTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: MenuBarButton(onPressed: onPressed),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('o botão desenha o ícone inclinado e chama o gesto', (
    tester,
  ) async {
    var opened = 0;
    await pumpButton(tester, onPressed: () => opened++);
    expect(find.byKey(const Key('slanted-menu-icon')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Abrir menu',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Menu'));
    await tester.pump();
    expect(opened, 1);
  });

  // O botão é a porta do `endDrawer`, e quem é desenhado fora da casca não tem
  // drawer para abrir. Um ícone ali seria enfeite: o widget some junto do gesto.
  testWidgets('sem gesto não há botão de menu na tela', (tester) async {
    await pumpButton(tester);
    expect(find.byKey(const Key('slanted-menu-icon')), findsNothing);
    expect(find.byTooltip('Menu'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
