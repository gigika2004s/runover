import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/screens/app_footer.dart';
import 'package:runover_app/services/cookie_consent.dart';
import 'package:runover_app/widgets/cookie_consent.dart';

void main() {
  test('consent round-trips through storage', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await CookieConsentStore.load(), isNull);

    await CookieConsentStore.save(CookieConsent.acceptedAll());
    var loaded = (await CookieConsentStore.load())!;
    expect(loaded.choice, CookieChoice.acceptedAll);
    expect(loaded.analytics, isTrue);
    expect(loaded.marketing, isTrue);

    await CookieConsentStore.save(
      const CookieConsent(
        choice: CookieChoice.customized,
        analytics: true,
      ),
    );
    loaded = (await CookieConsentStore.load())!;
    expect(loaded.choice, CookieChoice.customized);
    expect(loaded.analytics, isTrue);
    expect(loaded.marketing, isFalse);
  });

  testWidgets('banner appears once and accept-all persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => maybeShowCookieBanner(ctx),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(find.text('Este app utiliza cookies'), findsOneWidget);

    await tester.tap(find.text('Aceitar tudo'));
    await tester.pumpAndSettle();
    expect(find.text('Este app utiliza cookies'), findsNothing);
    expect(
      (await CookieConsentStore.load())!.choice,
      CookieChoice.acceptedAll,
    );

    // Com escolha salva, o banner não volta.
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    expect(find.text('Este app utiliza cookies'), findsNothing);
  });

  testWidgets('reject-essential persists essential-only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => maybeShowCookieBanner(ctx),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rejeitar não essenciais'));
    await tester.pumpAndSettle();
    final consent = (await CookieConsentStore.load())!;
    expect(consent.choice, CookieChoice.essentialOnly);
    expect(consent.analytics, isFalse);
  });

  testWidgets('footer link opens preferences that persist', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: AppFooter()),
        ),
      ),
    );
    await tester.tap(find.text('Gerenciar Cookies'));
    await tester.pumpAndSettle();
    expect(find.text('Gerenciar cookies'), findsOneWidget);

    await tester.tap(find.text('Desempenho e análise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar escolhas'));
    await tester.pumpAndSettle();

    final consent = (await CookieConsentStore.load())!;
    expect(consent.choice, CookieChoice.customized);
    expect(consent.analytics, isTrue);
    expect(consent.marketing, isFalse);
  });
}
