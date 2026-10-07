import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/centered_content.dart';
import 'app_footer.dart';
import 'tracking_screen.dart';

/// Formata ritmo em s/km no padrão 5'32".
String formatPace(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return "$minutes'$seconds\"";
}

/// Desafio de velocidade: melhor ritmo, resumo e últimas corridas.
class SpeedScreen extends StatefulWidget {
  const SpeedScreen({super.key});

  @override
  State<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends State<SpeedScreen> {
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _runs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    Map<String, dynamic>? progress;
    List<Map<String, dynamic>> runs = [];
    try {
      progress = await api.getProgress();
    } catch (_) {}
    try {
      runs = await api.listRuns();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _runs = runs.take(5).toList();
      _loading = false;
    });
  }

  Future<void> _startRun() async {
    final conquered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TrackingScreen()),
    );
    if (conquered == true && mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = _progress;
    final runs = (progress?['runs_count'] as num?)?.toInt() ?? 0;
    final distance = (progress?['distance_km'] as num?)?.toDouble() ?? 0;
    final longest = (progress?['longest_run_km'] as num?)?.toDouble() ?? 0;
    final bestPace = (progress?['fastest_pace_seconds_per_km'] as num?)
        ?.toInt();

    return Scaffold(
      appBar: AppBar(title: const Text('Desafio de velocidade')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: RunoverColors.route),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: RunoverColors.route,
              child: CenteredContent(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      color: colors.surfaceContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.secondary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.timer_outlined,
                                    color: colors.secondary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Melhor ritmo',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              bestPace == null
                                  ? 'Sem recorde ainda'
                                  : '${formatPace(bestPace)}/km',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              bestPace == null
                                  ? 'Corra ao menos 10 m para estrear o ranking.'
                                  : 'Menor ritmo médio entre suas corridas.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _SpeedStat(
                          label: 'Corridas',
                          value: '$runs',
                          icon: Icons.directions_run,
                        ),
                        const SizedBox(width: 12),
                        _SpeedStat(
                          label: 'Distância',
                          value:
                              '${distance.toStringAsFixed(1).replaceAll('.', ',')} km',
                          icon: Icons.route,
                        ),
                        const SizedBox(width: 12),
                        _SpeedStat(
                          label: 'Maior',
                          value:
                              '${longest.toStringAsFixed(1).replaceAll('.', ',')} km',
                          icon: Icons.emoji_events,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _startRun,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar corrida'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Últimas corridas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_runs.isEmpty)
                      Text(
                        'Nenhuma corrida registrada.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      )
                    else
                      for (final run in _runs)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.directions_run),
                            title: Text(
                              (run['name'] as String?)?.isNotEmpty == true
                                  ? run['name'] as String
                                  : 'Corrida',
                            ),
                            subtitle: Text(
                              '${(((run['distance_m'] as num?) ?? 0) / 1000).toStringAsFixed(2).replaceAll('.', ',')} km',
                            ),
                            trailing: Text(
                              (run['pace_seconds_per_km'] as num?) == null
                                  ? '—'
                                  : '${formatPace((run['pace_seconds_per_km'] as num).toInt())}/km',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 24),
                    const AppFooter(),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SpeedStat extends StatelessWidget {
  const _SpeedStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: RunoverColors.route),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
