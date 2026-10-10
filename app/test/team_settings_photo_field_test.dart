import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/team_settings_drawer.dart';

const _inlineAvatar = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg';

TeamDetail _team(String? photoUrl) => TeamDetail.fromJson({
  'id': 'team-test',
  'name': 'Lobos do Asfalto',
  'photo_url': photoUrl,
  'creator_username': 'misaia',
  'member_count': 1,
  'members': [
    {'username': 'misaia', 'photo_url': null},
  ],
  'total_score': 320,
  'territories_count': 15,
  'level': 1,
  'level_progress': 0.4,
  'points_to_next_level': 90,
});

Future<void> openDrawer(WidgetTester tester, String? photoUrl) async {
  tester.view.physicalSize = const Size(520, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = ApiClient(
    client: MockClient((request) async => http.Response('{}', 200)),
  );
  addTearDown(api.close);
  final state = AppState(api: api);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: buildRunoverTheme(),
        home: Scaffold(
          body: TeamSettingsDrawer(team: _team(photoUrl), onChanged: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o campo de link não recebe o base64 do avatar pronto', (
    tester,
  ) async {
    await openDrawer(tester, _inlineAvatar);

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Link da foto'),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.textContaining('A foto atual é um avatar pronto'), findsOneWidget);
  });

  testWidgets('"Usar link" não apaga a foto com o campo vazio', (
    tester,
  ) async {
    await openDrawer(tester, _inlineAvatar);

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Usar link'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Link da foto'),
      'https://exemplo.run/foto.png',
    );
    await tester.pump();
    final enabled = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Usar link'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('link digitado continua indo direto para a caixa', (
    tester,
  ) async {
    await openDrawer(tester, 'https://exemplo.run/lobos.png');

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Link da foto'),
    );
    expect(field.controller!.text, 'https://exemplo.run/lobos.png');
    expect(find.text('Remover foto'), findsOneWidget);
  });
}
