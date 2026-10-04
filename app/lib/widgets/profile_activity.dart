import 'package:flutter/material.dart';

import '../theme.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class ProfileMetric extends StatelessWidget {
  const ProfileMetric({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class ProfileActivity extends StatelessWidget {
  const ProfileActivity({super.key, required this.progress});
  final Map<String, dynamic> progress;

  String _number(num value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 1).replaceAll('.', ',');

  String _distance(Object? value) =>
      value is num && value.isFinite ? '${_number(value)} km' : '—';

  Iterable<Map<dynamic, dynamic>> _maps(Object? value) =>
      value is List ? value.whereType<Map<dynamic, dynamic>>() : const [];

  @override
  Widget build(BuildContext context) {
    final goals = _maps(progress['goals'])
        .where(
          (g) =>
              g['name'] is String &&
              g['unit'] is String &&
              g['value'] is num &&
              (g['value'] as num).isFinite &&
              g['target'] is num &&
              (g['target'] as num).isFinite &&
              (g['target'] as num) > 0,
        )
        .toList();
    final badges = _maps(
      progress['badges'],
    ).where((b) => b['name'] is String && b['earned'] is bool).toList();
    final weeklyDistance = goals.where((g) => g['unit'] == 'km').firstOrNull;
    final earned = badges.where((b) => b['earned'] == true).length;
    final empty = progress['runs_count'] == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RunoverColors.route.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_run,
                      color: RunoverColors.route,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Corrida',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Cada passo conta.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'ESTA SEMANA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                weeklyDistance == null
                    ? '—'
                    : '${_number(weeklyDistance['value'] as num)} km',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                empty
                    ? 'Sua próxima corrida começa uma nova história.'
                    : 'Continue construindo seu ritmo, uma corrida de cada vez.',
                style: const TextStyle(color: Colors.black54, height: 1.5),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(height: 1),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = [
                    ProfileMetric(
                      value: '${progress['runs_count'] ?? '—'}',
                      label: 'Atividades',
                    ),
                    ProfileMetric(
                      value: _distance(progress['distance_km']),
                      label: 'Distância total',
                    ),
                    ProfileMetric(
                      value: _distance(progress['longest_run_km']),
                      label: 'Maior corrida',
                    ),
                  ];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 20,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: constraints.maxWidth < 280
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 24) / 3,
                          child: metric,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Metas da semana',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pequenos objetivos, novas conquistas.',
                style: TextStyle(color: Colors.black54),
              ),
              for (final goal in goals) ...[
                const SizedBox(height: 20),
                Text(
                  goal['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: (goal['target'] as num) > 0
                        ? ((goal['value'] as num) / (goal['target'] as num))
                              .clamp(0.0, 1.0)
                        : 0,
                    color: RunoverColors.territory,
                    backgroundColor: RunoverColors.territory.withValues(
                      alpha: .10,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_number(goal['value'] as num)} / ${_number(goal['target'] as num)} ${goal['unit']}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                badges.isEmpty
                    ? 'Suas conquistas'
                    : 'Suas conquistas · $earned/${badges.length}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in badges)
                    Chip(
                      backgroundColor: badge['earned'] == true
                          ? RunoverColors.territory.withValues(alpha: .08)
                          : Colors.grey.shade50,
                      avatar: Icon(
                        badge['earned'] == true
                            ? Icons.verified_outlined
                            : Icons.lock_outline,
                        size: 18,
                        color: badge['earned'] == true
                            ? RunoverColors.territory
                            : Colors.black38,
                      ),
                      label: Text(badge['name'] as String),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
