import 'package:flutter/material.dart';

/// Paleta RUNOVER!: laranja de rota/GPS e azul-petróleo de território.
class RunoverColors {
  static const route = Color(0xFFD9531F);
  static const routeDark = Color(0xFFFF8A52);
  static const territory = Color(0xFF0E7F8F);
  static const territoryDark = Color(0xFF4FD6E3);
  static const ink = Color(0xFF161B22);
  static const paper = Color(0xFFF2F5F1);
}

ThemeData buildRunoverTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF101419) : RunoverColors.paper;
  final surface = isDark ? const Color(0xFF1B2229) : Colors.white;
  final foreground = isDark ? RunoverColors.paper : RunoverColors.ink;
  final primary = isDark ? RunoverColors.routeDark : RunoverColors.route;
  final secondary = isDark
      ? RunoverColors.territoryDark
      : RunoverColors.territory;
  final scheme = ColorScheme.fromSeed(
    seedColor: RunoverColors.route,
    primary: primary,
    secondary: secondary,
    brightness: brightness,
  ).copyWith(surface: surface);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: scheme.onSurface.withValues(alpha: 0.12),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: 0.16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
    dialogTheme: DialogThemeData(backgroundColor: surface),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RunoverColors.route,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.18)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
