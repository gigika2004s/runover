import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/screens/onboarding_screen.dart';
import 'package:runover_app/services/onboarding.dart';

void main() {
  test('flag do tutorial persiste', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await OnboardingStore.seen(), isFalse);
    await OnboardingStore.markSeen();
    expect(await OnboardingStore.seen(), isTrue);
  });

  testWidgets('pular sai do tutorial', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onDone: () => done = true),
      ),
    );
    expect(find.text('Bem-vindo ao RUNOVER!'), findsOneWidget);
    await tester.tap(find.text('Pular'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('avançar percorre as páginas até Começar', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onDone: () => done = true),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Avançar'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Pronto para correr?'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pump();
    expect(done, isTrue);
  });

  testWidgets('página expõe semântica de passo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onDone: () {})),
    );
    final semantics = tester.getSemantics(
      find.text('Bem-vindo ao RUNOVER!'),
    );
    expect(semantics.label, contains('Bem-vindo ao RUNOVER!'));
  });
}
