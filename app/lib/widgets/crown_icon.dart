import 'package:flutter/material.dart';

/// Coroa colorida por dono, igual ao protótipo do RF06 — o emoji 👑 é
/// recolorido sólido via [ColorFilter], em vez do ícone de troféu do Material.
class CrownIcon extends StatelessWidget {
  final Color color;
  final double size;
  const CrownIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Text('👑', style: TextStyle(fontSize: size, height: 1)),
    );
  }
}
