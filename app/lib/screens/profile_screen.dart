import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/level_badge.dart';
import 'terms_screen.dart';

/// RF05/RF13/RF19 — perfil, estatísticas, progressão e histórico do usuário.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String formatPlaytime(int seconds) {
    if (seconds <= 0) return '0min';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '${h}h ${m}min' : '${h}h';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;

    if (profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: RunoverColors.route),
      );
    }

    final hasPhoto = profile.photoUrl != null && profile.photoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _openEditSheet(context, profile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refreshProfile(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: RunoverColors.route.withValues(alpha: 0.15),
                backgroundImage: hasPhoto
                    ? NetworkImage(profile.photoUrl!)
                    : null,
                child: hasPhoto
                    ? null
                    : Text(
                        profile.username.isNotEmpty
                            ? profile.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: RunoverColors.route,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '@${profile.username}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 6),
            Center(child: LevelBadge(level: profile.level)),
            const SizedBox(height: 4),
            Center(
              child: Text(
                profile.rankPosition != null
                    ? '${profile.rankPosition}º lugar no ranking'
                    : 'Sem posição ainda',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (profile.teamName != null)
                      Chip(
                        avatar: const Icon(
                          Icons.groups,
                          size: 16,
                          color: RunoverColors.territory,
                        ),
                        label: Text(profile.teamName!),
                      ),
                    Chip(
                      avatar: Icon(
                        profile.isPublic ? Icons.public : Icons.lock_outline,
                        size: 16,
                        color: Colors.black54,
                      ),
                      label: Text(
                        profile.isPublic ? 'Perfil público' : 'Perfil privado',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LevelProgress(
                  level: profile.level,
                  progress: profile.levelProgress,
                  pointsToNext: profile.pointsToNextLevel,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Pontos',
                    value: '${profile.totalScore}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Territórios',
                    value: '${profile.territoriesCount}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Tempo de jogo',
                    value: formatPlaytime(profile.playSeconds),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(Icons.history),
              label: const Text('Ver histórico de conquistas'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('Termos de Uso e Política de Privacidade'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditSheet(BuildContext context, UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.fullName);
    final usernameCtrl = TextEditingController(text: profile.username);
    final photoCtrl = TextEditingController(text: profile.photoUrl ?? '');
    final passwordCtrl = TextEditingController();
    bool isPublic = profile.isPublic;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Editar perfil',
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: photoCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Foto de perfil — URL',
                    hintText: 'https://...  (deixe vazio para remover)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova senha (opcional)',
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPublic,
                  onChanged: (v) => setSheetState(() => isPublic = v),
                  title: const Text('Perfil público'),
                  subtitle: const Text(
                    'Se desligado, outros jogadores não veem seu perfil (RF05/RN13).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final appState = context.read<AppState>();
                    try {
                      await appState.api.updateProfile(
                        fullName: nameCtrl.text.trim(),
                        username: usernameCtrl.text.trim(),
                        photoUrl: photoCtrl.text.trim(),
                        password: passwordCtrl.text.isEmpty
                            ? null
                            : passwordCtrl.text,
                        isPublic: isPublic,
                      );
                      await appState.refreshProfile();
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    } on ApiException catch (e) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(
                          sheetCtx,
                        ).showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getMyHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: RunoverColors.route),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma atividade ainda — vá conquistar um território!',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              final positive = e.delta >= 0;
              return ListTile(
                leading: Icon(
                  positive ? Icons.emoji_events : Icons.trending_down,
                  color: positive ? RunoverColors.territory : Colors.redAccent,
                ),
                title: Text(e.territoryName ?? 'Território removido'),
                subtitle: Text(
                  '${e.reason} · ${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
                ),
                trailing: Text(
                  '${positive ? '+' : ''}${e.delta} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: positive
                        ? RunoverColors.territory
                        : Colors.redAccent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
