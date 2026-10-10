import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../screens/team_settings_screen.dart';
import '../screens/team_shop_screen.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';

JoinMode _joinModeOf(String raw) => switch (raw) {
  'open' => JoinMode.open,
  'invite_only' => JoinMode.inviteOnly,
  _ => JoinMode.approval,
};

String _joinModeApi(JoinMode mode) => switch (mode) {
  JoinMode.open => 'open',
  JoinMode.inviteOnly => 'invite_only',
  JoinMode.approval => 'approval',
};

String? _inviteLinkOf(TeamDetail team) =>
    team.inviteToken == null ? null : '/teams/join/${team.inviteToken}';

/// Configurações da equipe (dono/admin): foto, nome, convites e dissolução.
class TeamSettingsDrawer extends StatefulWidget {
  const TeamSettingsDrawer({
    super.key,
    required this.team,
    required this.onChanged,
  });

  final TeamDetail team;
  final VoidCallback onChanged;

  @override
  State<TeamSettingsDrawer> createState() => _TeamSettingsDrawerState();
}

class _TeamSettingsDrawerState extends State<TeamSettingsDrawer> {
  late final _nameCtrl = TextEditingController(text: widget.team.name);
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(ApiClient api) call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call(context.read<AppState>().api);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    final team = widget.team;
    final api = context.read<AppState>().api;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamSettingsScreen(
          initial: TeamSettings(
            name: team.name,
            joinMode: _joinModeOf(team.joinMode),
            listed: team.listed,
            notifyRisk: team.notifyRisk,
            notifyRequests: team.notifyRequests,
          ),
          memberCount: team.memberCount,
          pendingCount: team.pendingRequests.length,
          inviteLink: _inviteLinkOf(team),
          onSave: (settings) => api
              .updateTeam(
                id: team.id,
                name: settings.name,
                joinMode: _joinModeApi(settings.joinMode),
                listed: settings.listed,
                notifyRisk: settings.notifyRisk,
                notifyRequests: settings.notifyRequests,
              )
              .then((_) {}),
          onRegenerateInvite: () async {
            final updated = await api.regenerateTeamInvite(team.id);
            widget.onChanged();
            return _inviteLinkOf(updated);
          },
          onLeave: () async {
            try {
              await api.leaveTeam();
            } on ApiException catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.message)));
              }
              return;
            }
            if (!mounted) return;
            Navigator.of(context).pop();
            widget.onChanged();
            Navigator.of(context).pop();
          },
          onDelete: () async {
            try {
              await api.disbandTeam(team.id);
            } on ApiException catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.message)));
              }
              return;
            }
            if (!mounted) return;
            Navigator.of(context).pop();
            widget.onChanged();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) widget.onChanged();
  }

  Future<void> _disband() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dissolver equipe?'),
        content: Text(
          '${widget.team.name} deixará de existir para todos os membros. '
          'Territórios voltam a ficar livres. Não há como desfazer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Dissolver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run((api) => api.disbandTeam(widget.team.id));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Configurações',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              team.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nome da equipe',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              enabled: !_busy,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      (api) => api
                          .updateTeam(
                            id: team.id,
                            name: _nameCtrl.text.trim(),
                          )
                          .then((_) {}),
                    ),
              child: const Text('Salvar nome'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => TeamShopScreen(teamId: team.id),
                        ),
                      )
                      .then((_) => widget.onChanged()),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Loja da equipe'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _openSettings,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Ajustes da equipe'),
            ),
            const SizedBox(height: 20),
            Text(
              'Convites pendentes (${team.pendingRequests.length})',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (team.pendingRequests.isEmpty)
              const Text('Nenhum pedido aguardando.'),
            for (final req in team.pendingRequests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    req.username.isNotEmpty
                        ? req.username[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text('@${req.username}'),
                subtitle: const Text('Quer entrar na equipe'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Aceitar pedido',
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (api) => api
                                  .decideJoinRequest(team.id, req.id, true)
                                  .then((_) {}),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Recusar pedido',
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (api) => api
                                  .decideJoinRequest(team.id, req.id, false)
                                  .then((_) {}),
                            ),
                    ),
                  ],
                ),
              ),
            if (team.isOwner) ...[
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                'Zona de perigo',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _disband,
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('Dissolver equipe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
