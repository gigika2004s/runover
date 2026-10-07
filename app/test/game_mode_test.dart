import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/game_mode_screen.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

void main() {
  Future<void> pumpModes(
    WidgetTester tester, {
    required VoidCallback onPlay,
  }) async {
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
          home: GameModeScreen(onPlayDomination: onPlay),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os tres modos com um ativo', (tester) async {
    var played = 0;
    await pumpModes(tester, onPlay: () => played++);
    expect(find.text('Dominação de territórios'), findsOneWidget);
    expect(find.text('Desafio de velocidade'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Pit stop de equipe'),
      200,
    );
    expect(find.text('Pit stop de equipe'), findsOneWidget);
    expect(find.text('Ativo'), findsOneWidget);
    expect(find.text('Em breve'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Jogar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jogar'));
    await tester.pump();
    expect(played, 1);

    FilledButton playButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Jogar'),
        matching: find.byType(FilledButton),
      ),
    );
    FilledButton otherButton(String label) => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(FilledButton),
      ),
    );
    expect(playButton().enabled, isTrue);
    expect(otherButton('Correr').enabled, isFalse);
    expect(otherButton('Entrar').enabled, isFalse);
    expect(tester.takeException(), isNull);
  });
}
