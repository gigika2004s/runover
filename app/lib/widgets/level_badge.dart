import 'package:flutter/material.dart';

import '../theme.dart';

/// RF11 / RN10 — selo compacto de nível (ex.: "Nv 3"), usado no ranking e
/// no perfil público.
class LevelBadge extends StatelessWidget {
  final int level;
  final Color color;
  const LevelBadge({
    super.key,
    required this.level,
    this.color = RunoverColors.territory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Nv $level',
        style: TextStyle(
          color: color,
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
