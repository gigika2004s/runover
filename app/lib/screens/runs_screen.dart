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
  @override
  void initState() {
    super.initState();
    _load();
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
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RunDetailScreen(run: data)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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

  Widget _goal(String name, num value, num target, String unit) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (value / target).clamp(0, 1).toDouble(),
          ),
          const SizedBox(height: 6),
          Text('$value / $target $unit'),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final team = progress?['team'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corridas'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
            if (_pending.isNotEmpty) ...[
              Text(
                'Neste aparelho',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
            ],
            if (progress != null) ...[
              Text(
                '${progress['runs_count']} corridas • ${progress['distance_km']} km',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Maior corrida: ${progress['longest_run_km']} km'),
              const SizedBox(height: 16),
              Text(
                'Metas da semana',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text('De segunda a domingo, pelo horário UTC.'),
              for (final g in progress['goals'])
                _goal(g['name'], g['value'], g['target'], g['unit']),
              const SizedBox(height: 12),
              Text('Medalhas', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: [
                  for (final b in progress['badges'])
                    Chip(
                      avatar: Icon(
                        b['earned'] ? Icons.emoji_events : Icons.lock_outline,
                        color: b['earned']
                            ? Colors.amber.shade800
                            : Colors.grey,
                      ),
                      label: Text(b['name']),
                    ),
                ],
              ),
              if (team != null) ...[
                const SizedBox(height: 16),
                _goal(
                  'Equipe ${team['name']}',
                  team['distance_km'],
                  team['target_km'],
                  'km nesta semana',
                ),
                for (final c in team['contributors'])
                  ListTile(
                    dense: true,
                    title: Text('@${c['username']}'),
                    trailing: Text('${c['distance_km']} km'),
                  ),
              ],
            ],
            const SizedBox(height: 20),
            Text(
              'Histórico de corridas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_runs.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.all(16),
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
          ],
        ),
      ),
    );
  }
}
