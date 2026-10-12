import 'package:flutter/material.dart';

import 'runover_ui.dart';

/// RF11 / RN10 — selo compacto de nível (ex.: "Nv 3"), usado no ranking e
/// no perfil público.
class LevelBadge extends StatelessWidget {
  final int level;

  /// Tinta do selo. Sem um valor fixo: o `RunoverColors.territory` padrão era
  /// a cor do tema claro e desaparecia no escuro, então o omissão resolve
  /// para o acento secundário do tema em cada brilho.
  final Color? color;
  const LevelBadge({super.key, required this.level, this.color});

  @override
  Widget build(BuildContext context) {
    // Mesmo o acento vindo do tema ele ainda é cor de marca: como texto ele
    // passa por `legibleInk`, que garante 4,5:1 contra o cartão, o chip e a
    // barra do HUD do brilho atual.
    final ink = legibleInk(
      color ?? Theme.of(context).colorScheme.secondary,
      context,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ink.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Nv $level',
        style: TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// RF11 — barra de progresso até o próximo nível, com rótulo de quantos
/// pontos ainda faltam.
class LevelProgress extends StatelessWidget {
  final int level;
  final double progress; // 0..1
  final int pointsToNext;
  const LevelProgress({
    super.key,
    required this.level,
    required this.progress,
    required this.pointsToNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nível $level',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              'Nível ${level + 1}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Faltam $pointsToNext pts para o nível ${level + 1}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
