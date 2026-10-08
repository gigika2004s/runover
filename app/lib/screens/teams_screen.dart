import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/centered_content.dart';
import '../widgets/level_badge.dart';
import '../widgets/team_settings_drawer.dart';
import 'app_footer.dart';

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
    final team = _myTeam;
    return Theme(
      data: buildRunoverTheme(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFF12131A),
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined),
              SizedBox(width: 8),
              Text('Equipe'),
            ],
          ),
          actions: [
            if (team != null && team.isAdmin)
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Configurações da equipe',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
          ],
        ),
        endDrawer: team != null && team.isAdmin
            ? TeamSettingsDrawer(team: team, onChanged: _load)
            : null,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: RunoverColors.route),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: _myTeam != null
                    ? _MyTeamView(team: _myTeam!, onChanged: _load)
                    : _JoinOrCreateView(onChanged: _load, error: _error),
              ),
      ),
    );
  }
}

/// Arte estável por equipe a partir da galeria de avatares (sem campo
/// de imagem na API): o id define qual asset ilustra o card.
/// Usa FNV-1a porque `String.hashCode` varia entre execuções/plataformas.
String teamCardAsset(String teamId) {
  var hash = 0x811c9dc5;
  for (final unit in teamId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return presetAvatars[hash % presetAvatars.length].asset;
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().api.leaveTeam();
      onChanged();
    }
  }

  Future<void> _act(BuildContext context, Future<void> Function() call) async {
    try {
      await call();
      onChanged();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredContent(
      maxWidth: 1500,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: RunoverColors.territory.withValues(alpha: 0.15),
              child: Text(
                team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: RunoverColors.territory,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              team.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(
              'Criada por @${team.creatorUsername}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: LevelBadge(level: team.level)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _TeamLevelProgress(
                level: team.level,
                progress: team.levelProgress,
                totalScore: team.totalScore,
                pointsToNext: team.pointsToNextLevel,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Pontos',
                  value: '${team.totalScore}',
                  icon: Icons.star,
                  iconColor: const Color(0xFFE3A008),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Territórios',
                  value: '${team.territoriesCount}',
                  icon: Icons.map_outlined,
                  iconColor: RunoverColors.territory,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Membros (${team.memberCount})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < team.members.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 72),
                  Builder(
                    builder: (context) {
                      final m = team.members[i];
                      final isCreator = m.username == team.creatorUsername;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: RunoverColors.territory.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            m.username.isNotEmpty
                                ? m.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: RunoverColors.territory,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '@${m.username}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isCreator
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isCreator) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message: 'Criador da equipe',
                                child: Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Color(0xFFE3A008),
                                ),
                              ),
                            ] else if (m.isAdmin) ...[
                              const SizedBox(width: 6),
                              const Tooltip(
                                message: 'Admin da equipe',
                                child: Icon(
                                  Icons.shield_outlined,
                                  size: 18,
                                  color: RunoverColors.territory,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: isCreator
                            ? const Text('Criador da equipe')
                            : m.isAdmin
                            ? const Text('Admin da equipe')
                            : null,
                        trailing: team.isOwner && !isCreator
                            ? PopupMenuButton<String>(
                                tooltip: 'Ações de admin',
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) {
                                  if (action == 'promote') {
                                    _act(
                                      context,
                                      () => context
                                          .read<AppState>()
                                          .api
                                          .promoteAdmin(team.id, m.username),
                                    );
                                  } else {
                                    _act(
                                      context,
                                      () => context
                                          .read<AppState>()
                                          .api
                                          .demoteAdmin(team.id, m.username),
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (!m.isAdmin)
                                    const PopupMenuItem(
                                      value: 'promote',
                                      child: Text('Tornar admin'),
                                    )
                                  else
                                    const PopupMenuItem(
                                      value: 'demote',
                                      child: Text('Remover admin'),
                                    ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _leave(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sair da equipe'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          const AppFooter(),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progresso do nível da equipe com gradiente moderno, selo de
/// nível no início e legenda com pontos totais e quanto falta.
class _TeamLevelProgress extends StatelessWidget {
  final int level;
  final double progress; // 0..1
  final int totalScore;
  final int pointsToNext;
  const _TeamLevelProgress({
    required this.level,
    required this.progress,
    required this.totalScore,
    required this.pointsToNext,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            LevelBadge(level: level),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.08),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: clamped,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            RunoverColors.territory,
                            RunoverColors.route,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Progresso de Nível $level. Total de Pontos: $totalScore. '
          'Faltam $pointsToNext pts para o Nível ${level + 1}.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Card de equipe com arte de fundo e véu escuro para legibilidade.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.pending,
    required this.onJoin,
  });

  final TeamSummary team;
  final bool pending;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF3DDBB0),
      const Color(0xFF8B7CFF),
      const Color(0xFFFFC93C),
      const Color(0xFFFF7F4D),
    ];
    var hash = 0x811c9dc5;
    for (final unit in team.id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final accent = colors[hash % colors.length];
    final isNew =
        team.createdAt != null &&
        DateTime.now().difference(team.createdAt!).inDays < 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final details = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _teamTag(
                    isNew ? 'Nova' : 'Recrutando',
                    isNew ? const Color(0xFF8B7CFF) : _teamRecruitColor,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Criada por @${team.creatorUsername}',
                style: const TextStyle(color: Color(0xFFB8BCCB), fontSize: 15),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _teamStat(
                    '${team.memberCount} ${team.memberCount == 1 ? 'membro' : 'membros'}',
                  ),
                  _teamStat(
                    team.territoriesCount == 0
                        ? 'Seja o primeiro'
                        : '${team.territoriesCount} zonas',
                  ),
                ],
              ),
            ],
          ),
        );
        final join = Semantics(
          button: !pending,
          label: pending
              ? 'Pedido pendente em ${team.name}'
              : 'Solicitar entrada na equipe ${team.name}',
          child: OutlinedButton(
            key: Key('team-join-${team.id}'),
            onPressed: pending ? null : onJoin,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(pending ? 'Aguardando aprovação' : 'Solicitar entrada'),
          ),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1E2B),
            border: Border.all(color: const Color(0xFF2A2D3D)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0xFF0A0B10), offset: Offset(0, 5)),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _teamAvatar(team, accent),
                        const SizedBox(width: 16),
                        details,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: join),
                  ],
                )
              : Row(
                  children: [
                    _teamAvatar(team, accent),
                    const SizedBox(width: 24),
                    details,
                    const SizedBox(width: 16),
                    join,
                  ],
                ),
        );
      },
    );
  }

  static const _teamRecruitColor = Color(0xFF3DDBB0);

  Widget _teamAvatar(TeamSummary team, Color accent) => Container(
    width: 84,
    height: 84,
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.15),
      border: Border.all(color: accent, width: 1.5),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Icon(Icons.groups_outlined, size: 38, color: accent),
  );

  Widget _teamTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF17131A),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _teamStat(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF252838),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFE1E3EC),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
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
  final _requested = <String>{};
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _teamsFuture = context.read<AppState>().api.listTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Criar equipe'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nome da equipe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(nameCtrl.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<AppState>().api.createTeam(name);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _join(TeamSummary team) async {
    try {
      await context.read<AppState>().api.joinTeam(team.id);
      if (mounted) setState(() => _requested.add(team.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Pedido duplicado: já está aguardando aprovação.
      if (e.statusCode == 409) {
        setState(() => _requested.add(team.id));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CenteredContent(
      maxWidth: 1500,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 28),
        children: [
          if (widget.error != null)
            _infoCard('Não foi possível carregar sua equipe. ${widget.error}'),
          _createBanner(),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar equipe pelo nome',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFF1C1E2B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2A2D3D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2A2D3D)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              _filterChip('all', 'Todas'),
              _filterChip('recruiting', 'Recrutando'),
              _filterChip('new', 'Novas'),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'EQUIPES DISPONÍVEIS',
            style: TextStyle(
              color: Color(0xFFB8BCCB),
              fontSize: 17,
              letterSpacing: .6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<TeamSummary>>(
            future: _teamsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: RunoverColors.route,
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    _infoCard(
                      'Não foi possível carregar as equipes disponíveis.',
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _teamsFuture = context
                            .read<AppState>()
                            .api
                            .listTeams(),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar de novo'),
                    ),
                  ],
                );
              }
              final query = _searchController.text.trim().toLowerCase();
              var teams = snapshot.data ?? const <TeamSummary>[];
              if (query.isNotEmpty) {
                teams = teams
                    .where((team) => team.name.toLowerCase().contains(query))
                    .toList();
              }
              if (_filter == 'new') {
                final cutoff = DateTime.now().subtract(const Duration(days: 7));
                teams = teams
                    .where(
                      (team) =>
                          team.createdAt != null &&
                          team.createdAt!.isAfter(cutoff),
                    )
                    .toList();
              }
              if (teams.isEmpty) {
                final message = query.isNotEmpty
                    ? 'Nenhuma equipe corresponde à busca.'
                    : _filter == 'new'
                    ? 'Nenhuma equipe nova nesta semana.'
                    : 'Nenhuma equipe criada ainda.';
                return _infoCard(message);
              }
              return Column(
                children: teams
                    .map(
                      (t) => _TeamCard(
                        team: t,
                        pending: _requested.contains(t.id),
                        onJoin: () => _join(t),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _createBanner() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF2A2240),
      border: Border.all(color: const Color(0xFF8B7CFF), width: 1.5),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(color: Color(0xFF0A0B10), offset: Offset(0, 6)),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final icon = Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: const Color(0xFF8B7CFF).withValues(alpha: .15),
            border: Border.all(color: const Color(0xFF8B7CFF)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.groups_outlined,
            color: Color(0xFFC9C2FF),
            size: 38,
          ),
        );
        final copy = const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Corra em grupo, domine mais',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Você ainda não tem equipe. Crie a sua ou entre em uma para conquistar territórios juntos.',
                style: TextStyle(color: Color(0xFFD9D4FF), fontSize: 16),
              ),
            ],
          ),
        );
        final button = FilledButton.icon(
          onPressed: _createTeam,
          icon: const Icon(Icons.add),
          label: const Text('Criar equipe'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF7F4D),
            foregroundColor: const Color(0xFF28140B),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
        );
        return constraints.maxWidth < 650
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [icon, const SizedBox(width: 16), copy]),
                  const SizedBox(height: 16),
                  button,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 24),
                  copy,
                  const SizedBox(width: 20),
                  button,
                ],
              );
      },
    ),
  );

  Widget _filterChip(String value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFF302018),
      backgroundColor: const Color(0xFF1C1E2B),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFFAE8D) : const Color(0xFFB8BCCB),
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFFF7F4D) : Colors.transparent,
      ),
      shape: const StadiumBorder(),
    );
  }

  Widget _infoCard(String message) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1E2B),
      border: Border.all(color: const Color(0xFF2A2D3D)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFFB8BCCB))),
  );
}
