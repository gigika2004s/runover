import 'package:flutter/material.dart';

/// Paleta do RUNOVER! — mesma linguagem visual da arquitetura do projeto:
/// laranja de "rota/GPS" como cor de ação, azul-petróleo de "território" como
/// cor de dados/mapa.
class RunoverColors {
  static const route = Color(0xFFD9531F);
  static const routeDark = Color(0xFFFF8A52);
  static const territory = Color(0xFF0E7F8F);
  static const territoryDark = Color(0xFF4FD6E3);
  static const ink = Color(0xFF161B22);
  static const paper = Color(0xFFF2F5F1);
}

ThemeData buildRunoverTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RunoverColors.route,
    primary: RunoverColors.route,
    secondary: RunoverColors.territory,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RunoverColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: RunoverColors.paper,
      foregroundColor: RunoverColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RunoverColors.route,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
