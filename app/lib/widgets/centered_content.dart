import 'package:flutter/material.dart';

/// Largura máxima do conteúdo em telas largas (web/desktop).
const double kContentMaxWidth = 720;

/// Centraliza o conteúdo com largura máxima em telas largas (web/desktop).
/// No celular, onde a largura é menor que [maxWidth], ocupa a tela toda.
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
