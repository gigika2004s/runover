import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/game_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A barra e o drawer são o mesmo jogo de abas: este fixture só precisa de um
/// perfil para a ficha da conta e o avatar do Perfil.
Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final api = ApiClient(
    client: MockClient((_) async => http.Response('{}', 200)),
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
      'presence': 'nao_incomodar',
    });
  addTearDown(state.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildRunoverTheme(), home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
}

void main() {
  test('as cinco abas são as mesmas da barra e do menu', () {
    expect(kGameTabs.map((tab) => tab.label), [
      'Mapa',
      'Corridas',
      'Ranking',
      'Equipe',
      'Perfil',
    ]);
    expect(kTeamTabIndex, kGameTabs.indexWhere((tab) => tab.label == 'Equipe'));
    expect(
      kProfileTabIndex,
      kGameTabs.indexWhere((tab) => tab.label == 'Perfil'),
    );
  });

  testWidgets('the bottom bar carries every tab and selects by tap', (
    tester,
  ) async {
    final selected = <int>[];
    await _pump(
      tester,
      const Size(390, 844),
      GameNavBar(index: 1, onSelect: selected.add),
    );

    for (final tab in kGameTabs) {
      expect(find.text(tab.label), findsOneWidget);
    }
    await tester.tap(find.text('Ranking'));
    await tester.pump();
    expect(selected, [2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bottom bar fits the narrowest phone', (tester) async {
    await _pump(
      tester,
      const Size(320, 640),
      GameNavBar(index: 0, alerted: {kTeamTabIndex}, onSelect: (_) {}),
    );
    expect(find.text('Perfil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ficha da conta abre o perfil e não mostra presença', (
    tester,
  ) async {
    final selected = <int>[];
    await _pump(
      tester,
      const Size(1280, 800),
      AccountChip(onTap: () => selected.add(kProfileTabIndex)),
    );

    expect(find.text('@marina'), findsOneWidget);
    // A presença fica só no cartão de identidade do perfil; a ficha é atalho
    // para lá. O fixture guarda 'nao_incomodar' justamente para provar que o
    // rótulo não vaza para a navegação.
    expect(find.text('Não perturbe'), findsNothing);

    await tester.tap(find.text('@marina'));
    await tester.pump();
    expect(selected, [kProfileTabIndex]);
    expect(tester.takeException(), isNull);
  });
}
