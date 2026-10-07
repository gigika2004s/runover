import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import '../widgets/slanted_menu_icon.dart';
import 'app_footer.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';
import 'tracking_screen.dart';

/// Formata quilômetros no padrão pt-BR (8,4 km em vez de 8.40 km).
String formatKm(num value) {
  final trimmed = value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'[.,]$'), '');
  return '${trimmed.replaceAll('.', ',')} km';
}

/// Tela inicial leve: o mapa só é carregado quando o usuário pede.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenMenu,
    this.menuKey,
    this.startKey,
  });

  final VoidCallback? onOpenMenu;

  /// Chaves para o tour guiado destacar estes controles.
  final Key? menuKey;
  final Key? startKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TeamDetail? _team;
  Map<String, dynamic>? _progress;

  @override
  void initState() {
    super.initState();
    final api = context.read<AppState>().api;
    unawaited(
      context.read<AppState>().retryPendingRuns().catchError(
        (Object _) => false,
      ),
    );
    unawaited(_loadCardData(api));
  }

  /// Dados reais dos cards (equipe e corridas); falha silenciosa mantém
  /// os estados vazios honestos em vez de números inventados.
  Future<void> _loadCardData(ApiClient api) async {
    TeamDetail? team;
    Map<String, dynamic>? progress;
    try {
      team = await api.getMyTeam();
    } catch (_) {
      team = null;
    }
    try {
      progress = await api.getProgress();
    } catch (_) {
      progress = null;
    }
    if (!mounted) return;
    setState(() {
      _team = team;
      _progress = progress;
    });
  }

  List<String> _speedStats() {
    final runs = (_progress?['runs_count'] as num?)?.toInt() ?? 0;
    if (runs <= 0) return const ['Nenhuma corrida', 'Em breve'];
    final longest = (_progress?['longest_run_km'] as num?)?.toDouble() ?? 0;
    return [
      '$runs ${runs == 1 ? 'corrida' : 'corridas'}',
      'recorde ${formatKm(longest)}',
    ];
  }

  List<String> _teamStats() {
    final team = _team;
    if (team == null) return const ['Sem equipe', 'Crie ou entre'];
    final members = team.memberCount;
    return [
      '$members ${members == 1 ? 'membro' : 'membros'}',
      '${team.onlineCount} online',
      'Nv ${team.level}',
    ];
  }

  String? _teamBadge() {
    final team = _team;
    if (team == null) return null;
    final pending = team.pendingRequests.length;
    if (pending > 0) {
      return '$pending ${pending == 1 ? 'pedido' : 'pedidos'}';
    }
    if (team.onlineCount > 0) return '${team.onlineCount} online';
    return null;
  }

  void _startRun() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TrackingScreen()));
  }

  void _openMap() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = context.watch<AppState>().profile;
    final zones = profile?.territoriesCount ?? 0;
    final rank = profile?.rankPosition;

    return Scaffold(
      body: SafeArea(
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
            Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Abrir menu',
                  child: IconButton(
                    key: widget.menuKey,
                    tooltip: 'Menu',
                    icon: const SlantedMenuIcon(),
                    onPressed: widget.onOpenMenu,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notificações',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'RUNOVER!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/runner.png',
                height: 44,
                color: colors.onSurface,
                semanticLabel: 'Ícone RUNOVER!',
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Domine territórios correndo.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: widget.startKey,
                onPressed: _startRun,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 22,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Iniciar corrida'),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver mapa de territórios'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Escolha seu modo',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Cards dimensionados pelo conteúdo (IntrinsicHeight): sem altura
            // fixa, então fontes grandes de acessibilidade não estouram.
            // Centralizados quando cabem na tela; rolagem horizontal
            // quando passam da largura.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ModeCard(
                          icon: Icons.map_outlined,
                          accent: colors.primary,
                          title: 'Dominação de territórios',
                          description:
                              'Corra, reclame zonas no mapa e defenda o que é seu.',
                          badgeText: 'Em andamento',
                          stats: [
                            '$zones ${zones == 1 ? 'zona sua' : 'zonas suas'}',
                            if (rank != null) 'Ranking #$rank',
                          ],
                          buttonText: 'Jogar',
                          isSelected: true,
                          onPlay: _openMap,
                        ),
                        const SizedBox(width: 16),
                        _ModeCard(
                          icon: Icons.timer_outlined,
                          accent: colors.secondary,
                          title: 'Desafio de velocidade F1',
                          description:
                              'Voltas cronometradas. Bata seu recorde e suba no ranking.',
                          badgeText: null,
                          stats: _speedStats(),
                          buttonText: 'Correr',
                          isSelected: false,
                          onPlay: null,
                        ),
                        const SizedBox(width: 16),
                        _ModeCard(
                          icon: Icons.groups_outlined,
                          accent: colors.tertiary,
                          title: 'Pit stop de equipe',
                          description:
                              'Una forças com o time e cumpra objetivos relâmpago.',
                          badgeText: _teamBadge(),
                          stats: _teamStats(),
                          buttonText: 'Entrar',
                          isSelected: false,
                          onPlay: null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}

/// Card de modo de jogo como no design: ícone em tile, badge, título,
/// descrição, chips de stats e botão de ação em largura total.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.stats,
    required this.buttonText,
    required this.isSelected,
    required this.onPlay,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final String? badgeText;
  final List<String> stats;
  final String buttonText;
  final bool isSelected;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badge = badgeText;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? accent : colors.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              if (badge != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stat in stats)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stat,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isSelected ? accent : null,
                foregroundColor: isSelected ? colors.onPrimary : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: isSelected ? onPlay : null,
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
