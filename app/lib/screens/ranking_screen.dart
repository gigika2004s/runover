import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/level_badge.dart';
import 'app_footer.dart';
import 'public_profile_screen.dart';

/// RF12/RN11 — ranking sempre recalculado ao vivo pelo back-end, com
/// jogadores e equipes juntos (o diagrama de classes liga Ranking tanto a
/// Usuario quanto a Equipe).
///
/// A tela tem duas abas (Jogadores | Equipes) com a mesma identidade visual:
/// cabeçalho com a marca, pódio dinâmico com os 3 primeiros de cada aba,
/// listagem consistente do restante e CTA contextual de nível.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<RankingEntry>> _future;
  late TabController _tabController;

  static const _gold = Color(0xFFE3A008);
  static const _silver = Color(0xFF9AA5B1);
  static const _bronze = Color(0xFFB0793B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _future = context.read<AppState>().api.getRanking();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Rebuild para que o CTA ("Subir de Nível") acompanhe a aba ativa.
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  bool get _teamsTab => _tabController.index == 1;

  Future<void> _reload() async {
    setState(() => _future = context.read<AppState>().api.getRanking());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            TabBar(
              controller: _tabController,
              labelColor: RunoverColors.route,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicatorColor: RunoverColors.route,
              tabs: const [
                Tab(text: 'Jogadores'),
                Tab(text: 'Equipes'),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                color: RunoverColors.route,
                child: FutureBuilder<List<RankingEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: RunoverColors.route,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 48),
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Não foi possível carregar o ranking. Arraste para tentar de novo.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    }
                    final entries = snapshot.data ?? const <RankingEntry>[];
                    final users = entries
                        .where((e) => e.ownerType == 'user')
                        .toList();
                    final teams = entries
                        .where((e) => e.ownerType == 'team')
                        .toList();
                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _rankingList(
                          users,
                          profile?.username ?? '',
                          profile?.teamName,
                          isTeam: false,
                        ),
                        _rankingList(
                          teams,
                          profile?.username ?? '',
                          profile?.teamName,
                          isTeam: true,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            _levelUpCta(),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho: logotipo RUNOVER! à esquerda e título "Ranking Geral" abaixo.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                // Cor do tema (não fixa): "RUN" some no fundo escuro com
                // uma cor escura fixa e some no fundo claro com branco fixo.
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: [
                const TextSpan(text: 'RUN'),
                const TextSpan(
                  text: 'OVER!',
                  style: TextStyle(color: RunoverColors.route),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ranking Geral',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            _teamsTab
                ? 'As equipes com mais territórios dominados.'
                : 'Os jogadores com mais territórios dominados.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Aba de ranking: pódio com os 3 primeiros + listagem do restante.
  /// As posições exibidas são relativas à aba ativa.
  Widget _rankingList(
    List<RankingEntry> entries,
    String myUsername,
    String? myTeamName, {
    required bool isTeam,
  }) {
    if (entries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(
            isTeam ? Icons.groups_outlined : Icons.emoji_events_outlined,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 12),
          Text(
            isTeam
                ? 'Nenhuma equipe dominou território ainda.'
                : 'Ninguém dominou território ainda. Seja o primeiro!',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const AppFooter(),
        ],
      );
    }
    final podium = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _podium(podium, myUsername, myTeamName),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 8),
          // O pódio ocupa as posições 1–3 da aba.
          for (var i = 0; i < rest.length; i++)
            _entryCard(
              rest[i],
              displayPosition: i + 4,
              myUsername: myUsername,
              myTeamName: myTeamName,
            ),
        ],
        const SizedBox(height: 24),
        const AppFooter(),
      ],
    );
  }

  /// Pódio dinâmico: os 3 primeiros da aba ativa, com medalhas
  /// (ouro, prata e bronze), avatar e nível.
  Widget _podium(
    List<RankingEntry> top,
    String myUsername,
    String? myTeamName,
  ) {
    // Ordem visual de pódio: 2º à esquerda, 1º ao centro (destaque), 3º à
    // direita. Com menos de 3 colocados, mantém a ordem de classificação.
    // O lugar (0, 1, 2) é relativo à aba ativa.
    final List<(RankingEntry, int)> places;
    if (top.length == 3) {
      places = [(top[1], 1), (top[0], 0), (top[2], 2)];
    } else {
      places = [for (var i = 0; i < top.length; i++) (top[i], i)];
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (entry, place) in places)
              Expanded(
                child: _podiumPlace(
                  entry,
                  place,
                  _isMine(entry, myUsername, myTeamName),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _podiumPlace(RankingEntry entry, int place, bool isMe) {
    final medal = switch (place) {
      0 => _gold,
      1 => _silver,
      _ => _bronze,
    };
    final isFirst = place == 0;
    return GestureDetector(
      onTap: entry.ownerType == 'user' ? () => _openProfile(entry) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFirst ? Icons.emoji_events : Icons.military_tech,
            color: medal,
            size: isFirst ? 32 : 26,
          ),
          const SizedBox(height: 6),
          _avatar(entry, radius: isFirst ? 34 : 28, ring: medal, isMe: isMe),
          const SizedBox(height: 6),
          Text(
            entry.ownerType == 'user' ? '@${entry.name}' : entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isFirst || isMe ? FontWeight.w700 : FontWeight.w500,
              fontSize: isFirst ? 14 : 13,
            ),
          ),
          const SizedBox(height: 4),
          LevelBadge(level: entry.level),
          const SizedBox(height: 2),
          Text(
            '${entry.totalScore} pts',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Cartão da listagem: avatar, nome, selo de nível, territórios e pontos.
  Widget _entryCard(
    RankingEntry entry, {
    required int displayPosition,
    required String myUsername,
    required String? myTeamName,
  }) {
    final isMe = _isMine(entry, myUsername, myTeamName);
    final isUser = entry.ownerType == 'user';
    return Card(
      color: isMe ? RunoverColors.route.withValues(alpha: 0.08) : null,
      child: ListTile(
        onTap: isUser ? () => _openProfile(entry) : null,
        leading: _avatar(entry, radius: 22, isMe: isMe),
        title: Row(
          children: [
            Text(
              '$displayPositionº',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                isUser ? '@${entry.name}' : entry.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            LevelBadge(level: entry.level),
          ],
        ),
        subtitle: Text('${entry.territoriesCount} Territórios dominados(s)'),
        trailing: Text(
          '${entry.totalScore} pts',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _avatar(
    RankingEntry entry, {
    required double radius,
    Color? ring,
    required bool isMe,
  }) {
    final photo = profileImageProvider(entry.photoUrl);
    final initial = entry.name.isNotEmpty
        ? entry.name.characters.first.toUpperCase()
        : '?';
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: (ring ?? RunoverColors.territory).withValues(
        alpha: photo == null ? 0.15 : 1,
      ),
      foregroundImage: photo,
      onForegroundImageError: photo != null ? (_, _) {} : null,
      child: photo == null
          ? Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.8,
                color: ring ?? RunoverColors.territory,
              ),
            )
          : null,
    );
    if (ring == null && !isMe) return avatar;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ring ?? RunoverColors.route.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: avatar,
    );
  }

  bool _isMine(RankingEntry e, String myUsername, String? myTeamName) {
    return e.ownerType == 'user'
        ? e.name == myUsername
        : e.name == myTeamName;
  }

  void _openProfile(RankingEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(username: entry.name),
      ),
    );
  }

  /// CTA centralizado, adaptado à aba ativa (jogador ou equipe).
  Widget _levelUpCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Center(
        child: FilledButton.tonal(
          onPressed: _showLevelUpHelp,
          child: Text(
            _teamsTab
                ? 'Subir de Nível - Veja como subir sua equipe'
                : 'Subir de Nível - Veja como',
          ),
        ),
      ),
    );
  }

  /// Explica como subir de nível (RF11/RN10): pontos vêm de conquistas,
  /// perder território desconta, e o custo por nível é triangular
  /// (passo de 150 pts: Nv 2 = 150, Nv 3 = 450, Nv 4 = 900).
  void _showLevelUpHelp() {
    final teamsTab = _teamsTab;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamsTab
                  ? 'Como subir o nível da equipe'
                  : 'Como subir de nível',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              teamsTab
                  ? 'Os pontos da equipe vêm dos territórios dominados correndo em nome dela. Cada conquista soma pontos; perder um território desconta.'
                  : 'Domine territórios correndo para ganhar pontos. Cada conquista soma pontos; perder um território desconta.',
            ),
            const SizedBox(height: 12),
            const Text(
              'O custo sobe a cada nível (150 · 450 · 900 pts para os níveis 2, 3 e 4). Quanto mais territórios dominados, mais alto no Ranking Geral.',
            ),
          ],
        ),
      ),
    );
  }
}
