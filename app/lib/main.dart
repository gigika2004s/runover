import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme.dart';
import 'screens/auth_gate.dart';

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
    appState.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'RUNOVER!',
        debugShowCheckedModeBanner: false,
        theme: buildRunoverTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
