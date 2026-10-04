import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/level_badge.dart';

/// RF16/RN14/RN15 — UC10 (Criar/participar de equipe).
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  TeamDetail? _myTeam;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final team = await context.read<AppState>().api.getMyTeam();
      setState(() => _myTeam = team);
    } on ApiException {
      setState(() => _myTeam = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipe')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: RunoverColors.route))
          : RefreshIndicator(
              onRefresh: _load,
              child: _myTeam != null ? _MyTeamView(team: _myTeam!, onChanged: _load) : _JoinOrCreateView(onChanged: _load, error: _error),
            ),
    );
  }
}

class _MyTeamView extends StatelessWidget {
  final TeamDetail team;
  final VoidCallback onChanged;
  const _MyTeamView({required this.team, required this.onChanged});

  Future<void> _leave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da equipe?'),
        content: Text('Você vai deixar de fazer parte de ${team.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().api.leaveTeam();
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: RunoverColors.territory.withValues(alpha: 0.15),
            child: Text(
              team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: RunoverColors.territory),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(team.name, style: Theme.of(context).textTheme.titleLarge)),
        Center(child: Text('Criada por @${team.creatorUsername}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        const SizedBox(height: 6),
        Center(child: LevelBadge(level: team.level)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LevelProgress(
              level: team.level,
              progress: team.levelProgress,
              pointsToNext: team.pointsToNextLevel,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Pontos', value: '${team.totalScore}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Territórios', value: '${team.territoriesCount}')),
          ],
        ),
        const SizedBox(height: 20),
        Text('Membros (${team.memberCount})', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...team.members.map((m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(m.username[0].toUpperCase())),
              title: Text('@${m.username}'),
              trailing: m.username == team.creatorUsername ? const Icon(Icons.star, color: RunoverColors.route) : null,
            )),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _leave(context),
          icon: const Icon(Icons.logout),
          label: const Text('Sair da equipe'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _JoinOrCreateView extends StatefulWidget {
  final VoidCallback onChanged;
  final String? error;
  const _JoinOrCreateView({required this.onChanged, required this.error});

  @override
  State<_JoinOrCreateView> createState() => _JoinOrCreateViewState();
}

class _JoinOrCreateViewState extends State<_JoinOrCreateView> {
  late Future<List<TeamSummary>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _teamsFuture = context.read<AppState>().api.listTeams();
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Criar equipe'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome da equipe')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogCtx).pop(nameCtrl.text.trim()), child: const Text('Criar')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<AppState>().api.createTeam(name);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _join(TeamSummary team) async {
    try {
      await context.read<AppState>().api.joinTeam(team.id);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Você ainda não faz parte de uma equipe. Crie uma ou entre em uma já existente pra dominar territórios em grupo.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _createTeam, icon: const Icon(Icons.add), label: const Text('Criar equipe')),
        const SizedBox(height: 24),
        Text('Equipes disponíveis', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<List<TeamSummary>>(
          future: _teamsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: RunoverColors.route)),
              );
            }
            final teams = snapshot.data!;
            if (teams.isEmpty) {
              return Text('Nenhuma equipe criada ainda.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
            }
            return Column(
              children: teams
                  .map((t) => Card(
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text('${t.memberCount} membro(s) · criada por @${t.creatorUsername}'),
                          trailing: TextButton(onPressed: () => _join(t), child: const Text('Entrar')),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
