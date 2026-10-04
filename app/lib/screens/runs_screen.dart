import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/run_store.dart';
import '../state/app_state.dart';
import 'run_detail_screen.dart';
import 'tracking_screen.dart';

class RunsScreen extends StatefulWidget {
  const RunsScreen({super.key});
  @override
  State<RunsScreen> createState() => _RunsScreenState();
}

class _RunsScreenState extends State<RunsScreen> {
  List<Map<String, dynamic>> _runs = [];
  List<RunDraft> _pending = [];
  Map<String, dynamic>? _progress;
  bool _loading = true;
  bool _more = true;
  String? _error;
  AppState? _observedState;
  int _observedRunsRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (identical(state, _observedState)) return;
    _observedState?.removeListener(_onAppStateChanged);
    _observedState = state;
    _observedRunsRevision = state.runsRevision;
    state.addListener(_onAppStateChanged);
  }

  void _onAppStateChanged() {
    final state = _observedState;
    if (state == null || state.runsRevision == _observedRunsRevision) return;
    _observedRunsRevision = state.runsRevision;
    if (mounted) _load();
  }

  @override
  void dispose() {
    _observedState?.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final state = context.read<AppState>();
    try {
      final pending = await RunStore(state.profile!.id).list();
      if (mounted) setState(() => _pending = pending);
      final runs = await state.api.listRuns(offset: more ? _runs.length : 0);
      final progress = await state.api.getProgress();
      if (!mounted) return;
      setState(() {
        _runs = more ? [..._runs, ...runs] : runs;
        _progress = progress;
        _more = runs.length == 20;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> run) async {
    try {
      final data = await context.read<AppState>().api.getRun(run['id']);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RunDetailScreen(run: data)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _resume(RunDraft draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackingScreen(draftId: draft.id)),
    );
    if (mounted) _load();
  }

  Future<void> _remove(RunDraft draft) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover cópia local?'),
        content: const Text(
          'Um percurso ainda não enviado será perdido. Se o servidor já recebeu a corrida, ela continuará no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await RunStore(context.read<AppState>().profile!.id).remove(draft.id);
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Não foi possível remover a cópia local.');
      }
    }
  }

  Widget _status() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_loading) const LinearProgressIndicator(),
      if (_error != null)
        Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
    ],
  );

  Widget _tab(List<Widget> children) => RefreshIndicator(
    onRefresh: () => _load(),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [_status(), ...children],
    ),
  );

  List<Widget> _history(BuildContext context) {
    final progress = _progress;
    final theme = Theme.of(context);
    return [
      if (_pending.isNotEmpty) ...[
        Text('Neste aparelho', style: theme.textTheme.titleMedium),
        for (final d in _pending)
          Card(
            child: ListTile(
              leading: Icon(
                d.queued
                    ? Icons.cloud_upload_outlined
                    : Icons.pause_circle_outline,
              ),
              title: Text(d.name.isEmpty ? 'Corrida sem título' : d.name),
              subtitle: Text(
                d.queued
                    ? 'Envio pendente — toque para tentar novamente'
                    : 'Percurso salvo — toque para continuar',
              ),
              onTap: () => _resume(d),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _remove(d),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
      if (progress != null) ...[
        Row(
          children: [
            _Stat(label: 'Corridas', value: '${progress['runs_count']}'),
            _Stat(label: 'Distância', value: '${progress['distance_km']} km'),
            _Stat(
              label: 'Maior corrida',
              value: '${progress['longest_run_km']} km',
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
      Text('Histórico de corridas', style: theme.textTheme.titleMedium),
      if (_runs.isEmpty && !_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Suas corridas aparecerão aqui, mesmo sem conquistar um território.',
          ),
        ),
      for (final r in _runs)
        Card(
          child: ListTile(
            leading: const Icon(Icons.directions_run),
            title: Text(r['name']),
            subtitle: Text(
              '${DateTime.parse(r['started_at']).toLocal().toString().substring(0, 16)} • ${((r['distance_m'] as num) / 1000).toStringAsFixed(2)} km',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(r),
          ),
        ),
      if (_more && _runs.isNotEmpty)
        TextButton(
          onPressed: _loading ? null : () => _load(more: true),
          child: const Text('Carregar mais'),
        ),
    ];
  }

  List<Widget> _challenges(BuildContext context) {
    final progress = _progress;
    if (progress == null) return const [];
    final theme = Theme.of(context);
    final goals = [
      for (final g in progress['goals'] as List) WeeklyGoal.fromJson(g),
    ];
    final team = progress['team'];
    final remaining = weekTimeLeft(progress['week_start'], DateTime.now());
    final featured = WeeklyGoal.featured(goals);
    return [
      if (featured != null) _FeaturedGoal(goal: featured, remaining: remaining),
      const SizedBox(height: 24),
      Text('Metas da semana', style: theme.textTheme.titleMedium),
      Text(
        remaining == null
            ? 'De segunda a domingo, pelo horário local.'
            : 'De segunda a domingo, pelo horário local • $remaining',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      for (final g in goals) _GoalTile(goal: g),
      if (team != null) ...[
        const SizedBox(height: 24),
        Text('Meta da equipe', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _GoalTile(
          goal: WeeklyGoal(
            name: 'Equipe ${team['name']}',
            value: team['distance_km'],
            target: team['target_km'],
            unit: 'km',
          ),
        ),
        for (final c in team['contributors'])
          ListTile(
            dense: true,
            title: Text('@${c['username']}'),
            trailing: Text('${c['distance_km']} km'),
          ),
      ],
      const SizedBox(height: 24),
      Text('Medalhas', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final b in progress['badges'])
            _Medal(name: b['name'], earned: b['earned'] == true),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Corridas'),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Histórico'),
              Tab(text: 'Desafios'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_tab(_history(context)), _tab(_challenges(context))],
        ),
      ),
    );
  }
}

class WeeklyGoal {
  const WeeklyGoal({
    required this.name,
    required this.value,
    required this.target,
    required this.unit,
  });

  factory WeeklyGoal.fromJson(Map<String, dynamic> j) => WeeklyGoal(
    name: j['name'],
    value: j['value'],
    target: j['target'],
    unit: j['unit'],
  );

  final String name;
  final num value;
  final num target;
  final String unit;

  bool get completed => value >= target;
  double get fraction =>
      target <= 0 ? 1.0 : (value / target).clamp(0, 1).toDouble();

  /// Meta em aberto mais perto de ser concluída; a primeira, se todas já foram.
  static WeeklyGoal? featured(List<WeeklyGoal> goals) {
    if (goals.isEmpty) return null;
    final open = goals.where((g) => !g.completed).toList();
    if (open.isEmpty) return goals.first;
    return open.reduce((a, b) => b.fraction > a.fraction ? b : a);
  }

  String get missing {
    final left = target - value;
    final text = left == left.roundToDouble()
        ? left.round().toString()
        : left.toStringAsFixed(1).replaceAll('.', ',');
    if (left == 1) {
      final singular = switch (unit) {
        'dias' => 'dia',
        'conquistas' => 'conquista',
        _ => unit,
      };
      return 'Falta 1 $singular';
    }
    return 'Faltam $text $unit';
  }
}

/// Tempo até o fim da semana (segunda 00:00 local + 7 dias).
String? weekTimeLeft(String? weekStartUtc, DateTime now) {
  if (weekStartUtc == null) return null;
  final start = DateTime.tryParse(weekStartUtc);
  if (start == null) return null;
  final left = start.add(const Duration(days: 7)).difference(now.toUtc());
  if (left.isNegative) return null;
  if (left.inDays >= 1) {
    return '${left.inDays}d ${left.inHours % 24}h restantes';
  }
  if (left.inHours >= 1) {
    return '${left.inHours}h ${left.inMinutes % 60}min restantes';
  }
  return '${left.inMinutes}min restantes';
}

IconData _goalIcon(String unit) => switch (unit) {
  'dias' => Icons.calendar_month,
  'conquistas' => Icons.flag,
  _ => Icons.directions_run,
};

class _GoalBadge extends StatelessWidget {
  const _GoalBadge({required this.goal});

  final WeeklyGoal goal;
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = goal.completed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? colors.primary : colors.primary.withValues(alpha: .12),
        border: Border.all(color: colors.primary, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check : _goalIcon(goal.unit),
            size: size * .34,
            color: done ? colors.onPrimary : colors.primary,
          ),
          Text(
            '${goal.target}',
            style: TextStyle(
              fontSize: size * .24,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: done ? colors.onPrimary : colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedGoal extends StatelessWidget {
  const _FeaturedGoal({required this.goal, required this.remaining});

  final WeeklyGoal goal;
  final String? remaining;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final onPrimary = colors.onPrimary;
    return Card(
      color: colors.primary,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.completed ? 'Meta concluída' : 'Próxima meta',
              style: TextStyle(color: onPrimary.withValues(alpha: .8)),
            ),
            const SizedBox(height: 6),
            Text(
              goal.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.fraction,
                minHeight: 10,
                color: onPrimary,
                backgroundColor: onPrimary.withValues(alpha: .25),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${goal.value} / ${goal.target} ${goal.unit}',
                    style: TextStyle(
                      color: onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  goal.completed ? 'Concluída' : goal.missing,
                  style: TextStyle(color: onPrimary),
                ),
              ],
            ),
            if (remaining != null) ...[
              const SizedBox(height: 4),
              Text(
                remaining!,
                style: TextStyle(color: onPrimary.withValues(alpha: .8)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final WeeklyGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _GoalBadge(goal: goal),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: goal.fraction),
                const SizedBox(height: 6),
                Text(
                  '${goal.value} / ${goal.target} ${goal.unit}'
                  '${goal.completed ? ' • Concluída' : ''}',
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.name, required this.earned});

  final String name;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: earned
                  ? Colors.amber.shade700
                  : colors.surfaceContainerHighest,
            ),
            child: Icon(
              earned ? Icons.emoji_events : Icons.lock_outline,
              color: earned ? Colors.white : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: earned ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
