import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'team_settings_screen_test.dart' show openTeamSettings, teamSettingsJson;

// A foto vive dentro das Configurações da equipe desde que a gaveta e a tela de
// ajustes viraram uma superfície só. Estes casos seguram a regrinha do campo de
// link: base64 de avatar pronto não entra na caixa.

const _inlineAvatar = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUg';

Future<void> _openPhoto(WidgetTester tester, String? photoUrl) async {
  await openTeamSettings(tester, teamSettingsJson(photoUrl: photoUrl));
  await tester.drag(
    find.byKey(const Key('team-settings-list')),
    const Offset(0, -260),
  );
  await tester.pump();
}

void main() {
  testWidgets('o campo de link não recebe o base64 do avatar pronto', (
    tester,
  ) async {
    await _openPhoto(tester, _inlineAvatar);
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Link da foto'),
    );
    expect(field.controller!.text, isEmpty);
    expect(
      find.textContaining('A foto atual é um avatar pronto'),
      findsOneWidget,
    );
  });

  testWidgets('"Usar link" não apaga a foto com o campo vazio', (
    tester,
  ) async {
    await _openPhoto(tester, _inlineAvatar);
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
    await _openPhoto(tester, 'https://exemplo.run/lobos.png');
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Link da foto'),
    );
    expect(field.controller!.text, 'https://exemplo.run/lobos.png');
    expect(find.text('Remover foto'), findsOneWidget);
  });
}
