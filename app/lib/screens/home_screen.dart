import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/game_mode_card.dart';
import '../widgets/play_mode_sheet.dart';
import '../widgets/runover_ui.dart';
import '../widgets/slanted_menu_icon.dart';
import 'app_footer.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';
import 'pass_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'team_hub_screen.dart';
import 'tracking_screen.dart';

/// Formata quilômetros no padrão pt-BR (8,4 km em vez de 8.40 km).
String formatKm(num value) {
  final trimmed = value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'[.,]$'), '');
  return '${trimmed.replaceAll('.', ',')} km';
}

/// Formata ritmo em s/km no padrão 5'32".
String formatPace(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return "$minutes'$seconds\"";
}

/// Tela inicial: HUD da conta, a meta real da semana, os três modos de jogo e
/// os painéis de passe e mercado.
///
/// O mapa só é carregado quando o usuário pede. As superfícies seguem o brilho
/// do tema ([Pal.of]); os cartões de modo mantêm o gradiente da cor do modo nos
/// dois temas, porque é a cor do modo que se reconhece.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenMenu, this.menuKey, this.startKey});

  final VoidCallback? onOpenMenu;

  /// Chaves para o tour guiado destacar estes controles.
  final Key? menuKey;

  /// Anexada ao botão JOGAR da Dominação: é para lá que o passo "Iniciar
  /// corrida" do tour aponta.
  final Key? startKey;

  /// Altura a partir da qual a home estica o grid em vez de rolar. É a altura
  /// natural do conteúdo na janela larga (HUD + meta + título + cartões +
  /// painéis + rodapé): abaixo dela a lista já é mais alta que a janela, então
  /// rolar não deixa faixa vazia embaixo.
  static const double fillHeight = 1000;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TeamDetail? _team;
  Map<String, dynamic>? _progress;
  bool _teamFailed = false;
  bool _progressFailed = false;

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

  /// Dados reais dos cards (equipe e corridas). Erro de rede não vira
  /// estado vazio: marca falha e oferece nova tentativa no próprio card.
  Future<void> _loadCardData(ApiClient api) async {
    TeamDetail? team;
    Map<String, dynamic>? progress;
    var teamFailed = false;
    var progressFailed = false;
    try {
      team = await api.getMyTeam();
    } catch (_) {
      teamFailed = true;
    }
    try {
      progress = await api.getProgress();
    } catch (_) {
      progressFailed = true;
    }
    if (!mounted) return;
    setState(() {
      _team = team;
      _progress = progress;
      _teamFailed = teamFailed;
      _progressFailed = progressFailed;
    });
  }

  void _retryCards() {
    unawaited(_loadCardData(context.read<AppState>().api));
  }

  List<String> _speedStats() {
    if (_progressFailed) return const ['Falha ao carregar', 'Tente de novo'];
    final runs = (_progress?['runs_count'] as num?)?.toInt() ?? 0;
    if (runs <= 0) return const ['Nenhuma corrida'];
    final longest = (_progress?['longest_run_km'] as num?)?.toDouble() ?? 0;
    return [
      '$runs ${runs == 1 ? 'corrida' : 'corridas'}',
      'recorde ${formatKm(longest)}',
    ];
  }

  String? _speedBadge() {
    if (_progressFailed) return null;
    final best = (_progress?['fastest_pace_seconds_per_km'] as num?)?.toInt();
    if (best == null) return null;
    return 'PB ${formatPace(best)}';
  }

  List<String> _teamStats() {
    if (_teamFailed) return const ['Falha ao carregar', 'Tente de novo'];
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

  /// Primeira meta da semana ainda não cumprida, no `GET /progress`. O banner
  /// da home anuncia uma meta do servidor — nunca um XP inventado.
  Map? _openGoal() {
    final goals = (_progress?['goals'] as List? ?? const []).whereType<Map>();
    for (final goal in goals) {
      final value = (goal['value'] as num?)?.toDouble() ?? 0;
      final target = (goal['target'] as num?)?.toDouble() ?? 0;
      if (value < target) return goal;
    }
    return null;
  }

  /// Jogar na Dominação começa pela escolha da mecânica — o mapa sozinho não
  /// diz o que fazer. Laço livre pula o mapa e abre o tracking direto; as
  /// outras duas passam pelo mapa já focado na mecânica (dica + camadas).
  void _playDomination() {
    showPlayModeSheet(
      context,
      onSelect: (mode) {
        switch (mode) {
          case PlayMode.freeLoop:
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TrackingScreen()));
          case PlayMode.huntWild:
          case PlayMode.challenge:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MapScreen(focus: mode)),
            );
        }
      },
    );
  }

  Future<void> _openTeam() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TeamHubScreen()));
    if (!mounted) return;
    unawaited(_loadCardData(context.read<AppState>().api));
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _openShop() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
    if (!mounted) return;
    try {
      await context.read<AppState>().refreshProfile();
    } catch (_) {}
  }

  /// O Desafio de velocidade continua na tela sem regra definida. O botão não
  /// finge que joga nem registra aviso que ninguém processa: ele explica.
  void _explainSpeedMode() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desafio de velocidade'),
        content: const Text(
          'As voltas cronometradas ainda não têm regra definida: sem o '
          'formato da prova não há o que cronometrar. Quando a regra fechar, '
          'o botão vira JOGAR.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final profile = context.watch<AppState>().profile;
    final zones = profile?.territoriesCount ?? 0;
    final rank = profile?.rankPosition;
    final level = profile?.level ?? 1;
    final levelProgress = profile?.levelProgress ?? 0;
    final streakDays =
        (_progress?['streak_days'] as num?)?.toInt() ??
        (_progress?['streakDays'] as num?)?.toInt() ??
        0;
    final coins = profile?.coinsBalance ?? 0;
    final name = profile?.username ?? 'Corredor';

    final modes = [
      GameMode(
        title: 'Dominação de territórios',
        description: 'Corra, reclame zonas no mapa e defenda o que é seu.',
        character: RCharacter.zona,
        gradient: RGrad.orange,
        action: 'Jogar',
        actionKey: widget.startKey,
        pills: [
          '$zones ${zones == 1 ? 'zona sua' : 'zonas suas'}',
          if (rank != null) 'Ranking #$rank',
        ],
        tag: 'Em andamento',
        onPlay: _playDomination,
      ),
      GameMode(
        title: 'Desafio de velocidade',
        description: 'Voltas cronometradas. Bata seu recorde e suba no ranking.',
        character: RCharacter.turbo,
        gradient: dimmedModeGradient(RGrad.gold, pal.panel, 0.45),
        // O modo ainda não tem regra definida: o card fica na tela como
        // antecipação, com o botão contando isso. A falha de carregamento
        // continua acionável porque o mesmo dado alimenta a sequência do HUD.
        action: _progressFailed ? 'Tentar de novo' : 'Em breve',
        ghost: !_progressFailed,
        pills: _speedStats(),
        tag: _speedBadge() ?? 'Em breve',
        onPlay: _progressFailed ? _retryCards : _explainSpeedMode,
      ),
      GameMode(
        title: 'Pit stop de equipe',
        description: 'Una forças com o time e cumpra objetivos relâmpago.',
        character: RCharacter.pit,
        gradient: RGrad.teal,
        action: _teamFailed ? 'Tentar de novo' : 'Entrar',
        pills: _teamStats(),
        tag: _teamBadge(),
        onPlay: _teamFailed ? _retryCards : _openTeam,
      ),
    ];

    final goalBanner = _GoalBanner(
      goal: _openGoal(),
      failed: _progressFailed,
      loading: _progress == null && !_progressFailed,
      onRetry: _retryCards,
    );
    final footer = const AppFooter();

    return ColoredBox(
      color: pal.panel,
      child: Column(
        children: [
          _Hud(
            name: name,
            level: level,
            levelProgress: levelProgress,
            streakDays: streakDays,
            coins: coins,
            menuKey: widget.menuKey,
            onProfileTap: _openProfile,
            onShopTap: _openShop,
            onNotificationsTap: _openNotifications,
            onMenuTap: widget.onOpenMenu,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final wide = c.maxWidth >= kModeGridWideWidth;
                final fills = wide && c.maxHeight >= HomeScreen.fillHeight;
                // Os dois ramos mostram os mesmos blocos, na mesma ordem; o
                // largo e alto só troca a lista rolante por uma coluna que
                // estica o grid na sobra.
                if (fills) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        goalBanner,
                        const SizedBox(height: 18),
                        const _SectionTitle(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: GameModeGrid(modes: modes, stretch: true),
                        ),
                        const SizedBox(height: 20),
                        _BottomPanels(
                          wide: true,
                          coins: coins,
                          onShopTap: _openShop,
                        ),
                        footer,
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    goalBanner,
                    const SizedBox(height: 18),
                    const _SectionTitle(),
                    const SizedBox(height: 12),
                    GameModeGrid(modes: modes),
                    const SizedBox(height: 20),
                    _BottomPanels(
                      wide: wide,
                      coins: coins,
                      onShopTap: _openShop,
                    ),
                    footer,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- HUD

class _Hud extends StatelessWidget {
  const _Hud({
    required this.name,
    required this.level,
    required this.levelProgress,
    required this.streakDays,
    required this.coins,
    required this.onProfileTap,
    required this.onShopTap,
    required this.onNotificationsTap,
    required this.menuKey,
    this.onMenuTap,
  });

  final String name;
  final int level, streakDays, coins;

  /// 0..1 do XP já ganho no nível atual: é o arco dourado da moldura.
  final double levelProgress;
  final VoidCallback onProfileTap;
  final VoidCallback onShopTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback? onMenuTap;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    // A moldura inteira é o alvo que abre o perfil — antes só o selo pequeno
    // respondia ao toque. Ela também é o anel de XP do nível.
    final avatar = Semantics(
      button: true,
      label: 'Abrir perfil',
      child: GestureDetector(
        onTap: onProfileTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _LevelRing(
                progress: levelProgress,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Pal.orange,
                    ),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'V',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2A1308),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Pal.purple,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    'NV $level',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // O número do nível fica no selo do avatar e o XP que falta para o próximo
    // fica no arco da moldura: a barra de XP não volta ao HUD.
    final identity = Expanded(
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );

    final streak = _StreakTier.of(streakDays);
    final pills = [
      _HudPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              streak.icon,
              color: streak.color,
              size: streak.size,
              shadows: streak.shadows.isEmpty ? null : streak.shadows,
            ),
            const SizedBox(width: 7),
            Text(
              '$streakDays ${streakDays == 1 ? 'dia' : 'dias'}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      _HudPill(
        onTap: onShopTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DracmaCoin(size: 20),
            const SizedBox(width: 7),
            Text(
              formatPoints(coins),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ];

    // Menu e notificações vivem no HUD, à direita das pílulas: na janela larga
    // a home não tem mais uma faixa só para eles.
    final actions = [
      IconButton(
        tooltip: 'Notificações',
        icon: const Icon(Icons.notifications_none),
        color: Colors.white,
        onPressed: onNotificationsTap,
      ),
      Semantics(
        button: true,
        label: 'Abrir menu',
        child: IconButton(
          key: menuKey,
          tooltip: 'Menu',
          icon: const SlantedMenuIcon(),
          color: Colors.white,
          onPressed: onMenuTap,
        ),
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: RGrad.hud,
        boxShadow: [
          BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 10),
          child: LayoutBuilder(
            builder: (_, c) => c.maxWidth >= 560
                ? Row(
                    children: [
                      avatar,
                      const SizedBox(width: 14),
                      identity,
                      ...pills,
                      ...actions,
                    ],
                  )
                : Column(
                    children: [
                      Row(children: [avatar, const SizedBox(width: 14), identity]),
                      const SizedBox(height: 8),
                      Row(
                        children: [...pills, const Spacer(), ...actions],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pílula escura do HUD (sequência, dracmas).
class _HudPill extends StatelessWidget {
  const _HudPill({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: pill),
    );
  }
}

/// A chama da sequência escala por faixa de dias: sem sequência ela se apaga, e
/// 150 dias não pode ter a mesma cara de 3.
///
/// As tintas são fixas porque a chama vive sobre a faixa do HUD, que é gradiente
/// nos dois temas: `pal.muted` escureceria demais no claro e apagaria no escuro.
class _StreakTier {
  const _StreakTier(this.icon, this.size, this.color, this.shadows);

  final IconData icon;
  final double size;
  final Color color;
  final List<Shadow> shadows;

  static const _glow = [Shadow(color: Color(0x99FFC93C), blurRadius: 10)];

  static _StreakTier of(int days) {
    if (days <= 0) {
      return const _StreakTier(
        Icons.local_fire_department_outlined,
        16,
        Color(0x8AFFFFFF),
        [],
      );
    }
    if (days < 7) {
      return const _StreakTier(
        Icons.local_fire_department,
        16,
        Pal.orange,
        [],
      );
    }
    if (days < 30) {
      return const _StreakTier(
        Icons.local_fire_department,
        20,
        Pal.orange,
        [],
      );
    }
    if (days < 100) {
      return const _StreakTier(
        Icons.local_fire_department,
        24,
        Pal.gold,
        [],
      );
    }
    return const _StreakTier(
      Icons.local_fire_department,
      26,
      Pal.gold,
      _glow,
    );
  }
}

/// A moldura do avatar como anel de XP do nível: trilho discreto com o arco
/// dourado crescendo no sentido do relógio a partir do topo.
class _LevelRing extends StatelessWidget {
  const _LevelRing({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LevelRingPainter(
        value: progress.clamp(0.0, 1.0),
        // O trilho é ouro apagado, não cinza: a moldura continua sendo a
        // moldura dourada do avatar mesmo com o nível zerado.
        track: Pal.gold.withValues(alpha: 0.28),
        fill: Pal.gold,
      ),
      child: child,
    );
  }
}

class _LevelRingPainter extends CustomPainter {
  const _LevelRingPainter({
    required this.value,
    required this.track,
    required this.fill,
  });

  final double value;
  final Color track;
  final Color fill;

  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - _stroke / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke,
    );
    if (value <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}

// ---------------------------------------------------------------- Meta

/// Banner da meta da semana. O texto e o "faltam X" vêm de uma meta real do
/// `GET /progress`; não há recompensa de XP anunciada porque a rota não define
/// nenhuma — o que a meta move é o progresso da temporada.
class _GoalBanner extends StatelessWidget {
  const _GoalBanner({
    required this.goal,
    required this.failed,
    required this.loading,
    required this.onRetry,
  });

  final Map? goal;
  final bool failed;
  final bool loading;
  final VoidCallback onRetry;

  String _progress(String name, num value, num target, String unit) =>
      '$name — ${formatNumber(value)} de ${formatNumber(target)} $unit'.trim();

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final open = failed || loading ? null : goal;
    final name = '${open?['name'] ?? ''}';
    final unit = '${open?['unit'] ?? ''}';
    final value = (open?['value'] as num?) ?? 0;
    final target = (open?['target'] as num?) ?? 0;
    final String text;
    if (loading) {
      text = 'Carregando as metas da semana…';
    } else if (failed) {
      text = 'Falha ao carregar as metas da semana.';
    } else if (open == null) {
      text = 'Todas as metas da semana foram cumpridas.';
    } else {
      text = _progress(name, value, target, unit);
    }
    // O "faltam X" é o que separa a meta cumprida: a meta do servidor não tem
    // recompensa de XP própria para anunciar.
    final String? remaining = open == null
        ? null
        : 'faltam ${formatNumber(target - value)} $unit'.trim();

    return GameCard(
      color: pal.hud,
      borderColor: pal.border,
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const CharacterAvatar(RCharacter.coach, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Color.lerp(pal.hud, pal.heading, 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'META DA SEMANA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: pal.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (failed) ...[
            const SizedBox(width: 10),
            GameButton(
              label: 'Tentar de novo',
              compact: true,
              ghost: true,
              onPressed: onRetry,
            ),
          ] else if (remaining != null) ...[
            const SizedBox(width: 10),
            _GoldPill(remaining),
          ],
        ],
      ),
    );
  }
}

/// Pílula dourada de destaque sobre o painel índigo.
class _GoldPill extends StatelessWidget {
  const _GoldPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Pal.gold,
      borderRadius: BorderRadius.circular(10),
      boxShadow: const [
        BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
      ],
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: Color(0xFF3A2A00),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Modos

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) => Text(
    'ESCOLHA SEU MODO',
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
      color: Pal.of(context).heading,
    ),
  );
}

// ---------------------------------------------------------------- Painéis

/// Passe de temporada e mercado lado a lado na janela larga, empilhados na
/// estreita. É a última faixa da home antes do rodapé.
class _BottomPanels extends StatelessWidget {
  const _BottomPanels({
    required this.wide,
    required this.coins,
    required this.onShopTap,
  });

  final bool wide;
  final int coins;
  final VoidCallback onShopTap;

  @override
  Widget build(BuildContext context) {
    final pass = const SeasonPanel();
    final market = _MarketPanel(coins: coins, onTap: onShopTap);
    if (!wide) {
      return Column(
        children: [pass, const SizedBox(height: 16), market],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: pass),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: market),
        ],
      ),
    );
  }
}

/// Chamada para o mercado interno: o saldo em dracmas e o botão que abre a
/// [ShopScreen].
class _MarketPanel extends StatelessWidget {
  const _MarketPanel({required this.coins, required this.onTap});

  final int coins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GameCard(
    gradient: RGrad.gold,
    radius: 20,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MERCADO',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            color: Pal.onAccent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Seu saldo de dracmas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4A3400).withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const DracmaCoin(size: 44, onGold: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                formatPoints(coins),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: Color(0xFF3A2A00),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GameButton(
          label: 'Explorar a loja',
          expand: true,
          big: true,
          background: const Color(0xFF3A2A00),
          foreground: Pal.gold,
          shadow: const Color(0x40000000),
          onPressed: onTap,
        ),
      ],
    ),
  );
}
