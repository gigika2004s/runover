import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Decide, com base no token salvo localmente, se mostra login ou o app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    switch (state.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: RunoverColors.route),
          ),
        );
      case AuthStatus.unavailable:
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.connectionError ?? 'Servidor indisponível.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: state.bootstrap,
                    child: const Text('Tentar novamente'),
                  ),
                  TextButton(
                    onPressed: state.logout,
                    child: const Text('Entrar com outra conta'),
                  ),
                ],
              ),
            ),
          ),
        );
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const HomeShell();
    }
  }
}
