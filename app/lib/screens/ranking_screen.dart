import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/level_badge.dart';
import 'public_profile_screen.dart';

/// RF12/RN11 — ranking sempre recalculado ao vivo pelo back-end, com
/// jogadores e equipes juntos (o diagrama de classes liga Ranking tanto a
/// Usuario quanto a Equipe).
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with SingleTickerProviderStateMixin {
  late Future<List<RankingEntry>> _future;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _future = context.read<AppState>().api.getRanking();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _future = context.read<AppState>().api.getRanking());
    await _future;
  }

  Widget _list(List<RankingEntry> entries, String myUsername, String? myTeamName) {
    if (entries.isEmpty) {
      return const Center(child: Text('Ninguém dominou território ainda. Seja o primeiro!'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = entries[i];
        final isMe = e.ownerType == 'user' ? e.name == myUsername : e.name == myTeamName;
        final isUser = e.ownerType == 'user';
        return Card(
          color: isMe ? RunoverColors.route.withValues(alpha: 0.08) : null,
          child: ListTile(
            onTap: isUser
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(username: e.name)),
                    )
                : null,
            leading: CircleAvatar(
              backgroundColor: i == 0
                  ? RunoverColors.route
                  : i == 1
                      ? RunoverColors.territory
                      : Colors.grey.shade400,
              child: Text('${e.position}', style: const TextStyle(color: Colors.white)),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    isUser ? '@${e.name}' : e.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: isMe ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                LevelBadge(level: e.level),
              ],
            ),
            subtitle: Text('${e.territoriesCount} território(s) dominado(s)'),
            trailing: Text('${e.totalScore} pts', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: RunoverColors.route,
          indicatorColor: RunoverColors.route,
          tabs: const [Tab(text: 'Jogadores'), Tab(text: 'Equipes')],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<RankingEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: RunoverColors.route));
            }
            final entries = snapshot.data!;
            final users = entries.where((e) => e.ownerType == 'user').toList();
            final teams = entries.where((e) => e.ownerType == 'team').toList();
            return TabBarView(
              controller: _tabController,
              children: [
                _list(users, profile?.username ?? '', profile?.teamName),
                _list(teams, profile?.username ?? '', profile?.teamName),
              ],
            );
          },
        ),
      ),
    );
  }
}
