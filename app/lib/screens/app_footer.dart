import 'package:flutter/material.dart';

import 'terms_screen.dart';

/// Compact footer shown as the last item of scrollable tab content —
/// it only appears at the end of the page, never pinned to the screen.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withValues(alpha: 0.68);

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text('© 2026 RUNOVER!', style: TextStyle(color: muted, fontSize: 12)),
          Text('·', style: TextStyle(color: muted, fontSize: 12)),
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Termos e privacidade'),
          ),
        ],
      ),
    );
  }
}
