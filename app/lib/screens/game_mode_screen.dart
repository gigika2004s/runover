import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Escolha do modo de jogo. Só Dominação existe de verdade; os demais
/// aparecem desabilitados como "em breve" em vez de botões mortos.
class GameModeScreen extends StatelessWidget {
  const GameModeScreen({super.key, this.onPlayDomination});

  final VoidCallback? onPlayDomination;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    final zones = profile?.territoriesCount ?? 0;
    final rank = profile?.rankPosition;
    return Scaffold(
      appBar: AppBar(title: const Text('Modos de jogo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Escolha seu modo',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Cada modo tem regras e ranking próprios.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _ModeCard(
            icon: Icons.map_outlined,
            accent: Theme.of(context).colorScheme.primary,
            title: 'Dominação de territórios',
            description:
                'Corra, reclame zonas no mapa e defenda o que é seu.',
            badge: 'Ativo',
            stats: [
              '$zones ${zones == 1 ? 'zona sua' : 'zonas suas'}',
              if (rank != null) 'Ranking #$rank',
            ],
            buttonText: 'Jogar',
            enabled: true,
            onPlay: onPlayDomination,
          ),
          const SizedBox(height: 16),
          _ModeCard(
            icon: Icons.timer_outlined,
            accent: Theme.of(context).colorScheme.secondary,
            title: 'Desafio de velocidade',
            description:
                'Voltas cronometradas em segmentos. Bata recordes e suba no ranking.',
            badge: 'Em breve',
            stats: const ['Voltas cronometradas', 'Recorde pessoal'],
            buttonText: 'Correr',
            enabled: false,
            onPlay: null,
          ),
          const SizedBox(height: 16),
          _ModeCard(
            icon: Icons.groups_outlined,
            accent: Theme.of(context).colorScheme.tertiary,
            title: 'Pit stop de equipe',
            description:
                'Una forças com o time e cumpra objetivos relâmpago.',
            badge: 'Em breve',
            stats: const ['Missões em equipe', 'Objetivos relâmpago'],
            buttonText: 'Entrar',
            enabled: false,
            onPlay: null,
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.badge,
    required this.stats,
    required this.buttonText,
    required this.enabled,
    required this.onPlay,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final String badge;
  final List<String> stats;
  final String buttonText;
  final bool enabled;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enabled ? accent : colors.outlineVariant,
          width: enabled ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: enabled
                        ? accent
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: enabled
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final stat in stats)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stat,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: enabled ? accent : null,
                  foregroundColor: enabled ? colors.onPrimary : null,
                ),
                onPressed: enabled ? onPlay : null,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
