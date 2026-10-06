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
}
