import 'package:flutter/material.dart';

/// Largura máxima do conteúdo em telas largas (web/desktop).
const double kContentMaxWidth = 720;

/// A partir daqui a janela é larga: cabe dividir a tela em bandas lado a lado,
/// em vez de uma coluna estreita no meio com meio mundo de vazio dos lados.
/// É o mesmo degrau que dá à barra inferior um canto para a ficha da conta
/// (`kAccountChipMinWidth`), e o app inteiro conhece só este número.
const double kWideWindowMinWidth = 900;

/// A janela atual é larga o bastante para as bandas lado a lado?
bool isWideWindow(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideWindowMinWidth;

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
