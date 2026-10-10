import 'dart:ui';

import 'package:flutter/material.dart';

/// Painel em vidro (glassmorphism): superfície semitransparente com desfoque
/// do conteúdo de trás, borda fina e clara de 1 px e sombra suave para dar a
/// sensação de que o painel flutua sobre o fundo.
///
/// O fundo é um [Material] translúcido (e não um `Container` com cor) de
/// propósito: assim os toques e salpicos de tinta ([InkWell], [ListTile])
/// do conteúdo continuam visíveis acima do vidro.
///
/// As cores saem do [ColorScheme] (funciona no tema claro e no escuro).
/// Use com moderação: cada painel custa um `BackdropFilter`, então reserve
/// para elementos fixos/flutuantes (navegação, menus, sobreposições) e nunca
/// para cada item de uma lista rolável.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.sigma = 12,
    this.opacity = 0.72,
  });

  final Widget child;

  /// Raio dos cantos (combine com a forma do hospedeiro, ex. o `Drawer`).
  final BorderRadiusGeometry borderRadius;

  /// Intensidade do desfoque do fundo.
  final double sigma;

  /// Opacidade da superfície (0–1). Maior = mais legível, menos "vidro".
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Material(
          color: scheme.surface.withValues(alpha: opacity),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: scheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          child: child,
        ),
      ),
    );
  }
}
