import 'package:flutter/material.dart';

/// Hambúrguer personalizado: três barras inclinadas nas cores do tema
/// (primária, secundária e neutra). A semântica vem do IconButton que
/// o envolve — este widget não adiciona nós próprios.
class SlantedMenuIcon extends StatelessWidget {
  const SlantedMenuIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      key: const Key('slanted-menu-icon'),
      width: 28,
      height: 24,
      child: CustomPaint(
        painter: _SlantedMenuPainter(
          top: colors.primary,
          middle: colors.secondary,
          bottom: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// O botão do menu lateral, no canto de cima de qualquer tela da casca.
///
/// É um widget só porque o gesto é um só: a home, o painel do ranking e as
/// demais telas abrem todas o mesmo `endDrawer`. Sem [onPressed] não há menu a
/// abrir — a tela desenhada fora da casca (teste, rota empilhada) fica sem o
/// botão, em vez de ganhar um ícone decorativo.
class MenuBarButton extends StatelessWidget {
  const MenuBarButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    if (onPressed == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Abrir menu',
      child: IconButton(
        tooltip: 'Menu',
        icon: const SlantedMenuIcon(),
        onPressed: onPressed,
      ),
    );
  }
}

class _SlantedMenuPainter extends CustomPainter {
  const _SlantedMenuPainter({
    required this.top,
    required this.middle,
    required this.bottom,
  });

  final Color top;
  final Color middle;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const slant = 8.0;
    final spacing = size.height / 3;
    paint.color = top;
    canvas.drawLine(
      Offset(slant, spacing * 0.5),
      Offset(0, spacing * 1.5),
      paint,
    );
    paint.color = middle;
    canvas.drawLine(
      Offset(slant + 8, spacing * 0.5),
      Offset(8, spacing * 1.5),
      paint,
    );
    paint.color = bottom;
    canvas.drawLine(
      Offset(slant + 16, spacing * 0.5),
      Offset(16, spacing * 1.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SlantedMenuPainter oldDelegate) =>
      oldDelegate.top != top ||
      oldDelegate.middle != middle ||
      oldDelegate.bottom != bottom;
}
