import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme.dart';
import 'screens/auth_gate.dart';
import 'screens/onboarding_screen.dart';
import 'services/onboarding.dart';

void main() {
  runApp(const RunoverApp());
}

class RunoverApp extends StatefulWidget {
  const RunoverApp({super.key});

  @override
  State<RunoverApp> createState() => _RunoverAppState();
}

class _RunoverAppState extends State<RunoverApp> {
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    appState = AppState();
    appState.loadThemeMode();
    appState.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'RUNOVER!',
          debugShowCheckedModeBanner: false,
          theme: buildRunoverTheme(),
          darkTheme: buildRunoverTheme(brightness: Brightness.dark),
          themeMode: state.themeMode,
          home: const _LaunchGate(),
        ),
      ),
    );
  }
}

/// Mostra o tutorial apenas na primeira abertura; depois, o fluxo normal.
class _LaunchGate extends StatefulWidget {
  const _LaunchGate();

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool seen = true;
    try {
      seen = await OnboardingStore.seen();
    } catch (_) {
      // Sem leitura: segue para o app em vez de travar no indicador.
    }
    if (mounted) setState(() => _seen = seen);
  }

  Future<void> _finish() async {
    try {
      await OnboardingStore.markSeen();
    } catch (_) {
      // Sem gravação: segue mesmo assim; o tutorial pode reaparecer.
    }
    if (mounted) setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final seen = _seen;
    if (seen == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!seen) return OnboardingScreen(onDone: _finish);
    return const AuthGate();
  }
}
