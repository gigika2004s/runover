import 'package:flutter/material.dart';

import '../screens/terms_screen.dart';
import '../services/cookie_consent.dart';

/// Mostra o banner de consentimento apenas quando o usuário ainda não
/// escolheu (primeira abertura ou dados limpos).
Future<void> maybeShowCookieBanner(BuildContext context) async {
  final existing = await CookieConsentStore.load();
  if (!context.mounted || existing != null) return;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => const _CookieBanner(),
  );
}

/// Reabre as preferências a qualquer momento (link "Gerenciar Cookies").
Future<void> showCookiePreferences(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CookiePreferences(),
  );
}

Future<void> _choose(BuildContext context, CookieConsent consent) async {
  await CookieConsentStore.save(consent);
  if (context.mounted) Navigator.of(context).pop();
}

class _CookieBanner extends StatelessWidget {
  const _CookieBanner();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Este app utiliza cookies',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Utilizamos cookies essenciais para fazer o app funcionar. Também usamos cookies adicionais para melhorar sua experiência e medir desempenho. Para mais informações, visite nossa Política de Privacidade.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                ),
                child: const Text('Política de Privacidade'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _choose(context, CookieConsent.acceptedAll()),
              child: const Text('Aceitar tudo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _choose(context, CookieConsent.essentialOnly()),
              child: const Text('Rejeitar não essenciais'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                showCookiePreferences(context);
              },
              child: const Text('Personalizar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookiePreferences extends StatefulWidget {
  const _CookiePreferences();

  @override
  State<_CookiePreferences> createState() => _CookiePreferencesState();
}

class _CookiePreferencesState extends State<_CookiePreferences> {
  bool _analytics = false;
  bool _marketing = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    CookieConsentStore.load().then((consent) {
      if (!mounted) return;
      setState(() {
        _analytics = consent?.analytics ?? false;
        _marketing = consent?.marketing ?? false;
        _loaded = true;
      });
    });
  }

  Future<void> _save() async {
    final both = _analytics && _marketing;
    await CookieConsentStore.save(
      both
          ? CookieConsent.acceptedAll()
          : CookieConsent(
              choice: CookieChoice.customized,
              analytics: _analytics,
              marketing: _marketing,
            ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Gerenciar cookies',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Essenciais'),
              subtitle: const Text('Necessários para o app funcionar.'),
              value: true,
              onChanged: null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desempenho e análise'),
              subtitle: const Text('Ajudam a medir o uso do app.'),
              value: _analytics,
              onChanged: _loaded
                  ? (value) => setState(() => _analytics = value)
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publicidade direcionada'),
              subtitle: const Text('Personalizam ofertas e conteúdo.'),
              value: _marketing,
              onChanged: _loaded
                  ? (value) => setState(() => _marketing = value)
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Salvar escolhas'),
            ),
          ],
        ),
      ),
    );
  }
}
