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
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const HomeShell();
    }
  }
}
