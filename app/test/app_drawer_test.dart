import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/app_drawer.dart';

import 'profile_screen_test.dart' show profileData;

void main() {
  Future<AppState> openDrawer(WidgetTester tester, {ValueChanged<int>? onTab}) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState()
      ..profile = UserProfile.fromJson(profileData)
      ..status = AuthStatus.signedIn;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: Scaffold(
            drawer: AppDrawer(
              selectedIndex: 0,
              onSelectTab: onTab ?? (_) {},
            ),
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('drawer mostra perfil e abas', (tester) async {
    await openDrawer(tester);
    expect(find.text('Marina Oliveira'), findsOneWidget);
    expect(find.text('@marina'), findsOneWidget);
    for (final label in ['Mapa', 'Corridas', 'Ranking', 'Equipe', 'Perfil']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Ver tutorial'), 200);
    expect(find.text('Ver tutorial'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sair'), 200);
    expect(find.text('Sair'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar numa aba seleciona e fecha', (tester) async {
    var selected = -1;
    await openDrawer(tester, onTab: (i) => selected = i);
    await tester.tap(find.text('Corridas'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.text('Ver tutorial'), findsNothing);
  });

  testWidgets('tocar no perfil abre a aba Perfil', (tester) async {
    var selected = -1;
    await openDrawer(tester, onTab: (i) => selected = i);
    await tester.tap(find.text('Marina Oliveira'));
    await tester.pumpAndSettle();
    expect(selected, 4);
  });

  testWidgets('ver tutorial pede o tour guiado', (tester) async {
    final state = await openDrawer(tester);
    expect(state.tourRequests, 0);
    await tester.scrollUntilVisible(find.text('Ver tutorial'), 200);
    await tester.tap(find.text('Ver tutorial'));
    await tester.pump();
    // O pedido chega ao AppState; o HomeShell exibe o tour.
    expect(state.tourRequests, 1);
    expect(tester.takeException(), isNull);
  });
}
