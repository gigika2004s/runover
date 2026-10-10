import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import 'app_footer.dart';
import 'pass_screen.dart';

/// A trilha do passe: os tiers de baixo para cima, ligados por uma serpentina,
/// com o corredor no ponto que o XP já alcançou.
class PassTrailScreen extends StatefulWidget {
  const PassTrailScreen({super.key});

  @override
  State<PassTrailScreen> createState() => _PassTrailScreenState();
}

class _TrailData {
  const _TrailData({required this.status, required this.names});

  final Map<String, dynamic> status;
  final Map<String, String> names;
}

class _PassTrailScreenState extends State<PassTrailScreen>
    with AccountWatcher<PassTrailScreen> {
  late Future<_TrailData> _future = _startLoad();
  bool _busy = false;

  @override
  bool get busy => _busy;

  @override
  void onAccountChanged() => _reload();

  Future<_TrailData> _load(ApiClient api) async {
    final results = await Future.wait([
      api.getPassRunover(),
      api.getShopCatalog(scope: 'pass'),
    ]);
    final catalog = results[1] as List<ShopItem>;
    return _TrailData(
      status: results[0] as Map<String, dynamic>,
      names: {for (final c in catalog) c.id: c.name},
    );
  }

  /// A tela pode ser descartada antes da resposta chegar; um `Future` sem
  /// listener denuncia o próprio erro como exceção não tratada.
  Future<_TrailData> _startLoad() {
    final future = _load(context.read<AppState>().api);
    future.then<void>((_) {}, onError: (Object _) {});
    return future;
  }

  void _reload() {
    markRevisionSeen();
    setState(() {
      _future = _startLoad();
    });
  }

  Future<void> _claim(int tier, String track) async {
    if (_busy) return;
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await app.api.claimPassReward(tier, track);
      await app.refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recompensa resgatada!')));
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        flushAccountRefresh();
      }
    }
  }

  Future<void> _unlockPremium(int price) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trilha premium?'),
        content: Text(
          'Desbloqueia as recompensas premium desta temporada por '
          '${fmt(price)} moedas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await app.api.unlockPassPremium();
      await app.refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trilha premium desbloqueada!')),
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        flushAccountRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pass Runover')),
      body: FutureBuilder<_TrailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Não foi possível carregar o passe.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          final status = data.status;
          final tiers = (status['tiers'] as List? ?? const [])
              .whereType<Map>()
              .toList();
          final premium = status['premium_unlocked'] == true;
          final price = (status['premium_price_coins'] as num).toInt();
          return CenteredContent(
            maxWidth: 720,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PassSummary(status: status),
                  if (!premium) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _unlockPremium(price),
                      icon: const Icon(Icons.lock_open_outlined),
                      label: Text('Premium · ${fmt(price)} moedas'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC93C),
                        foregroundColor: const Color(0xFF1A0E08),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PassTrail(
                    tiers: tiers,
                    names: data.names,
                    points: (status['seasonal_points'] as num).toInt(),
                    premiumUnlocked: premium,
                    busy: _busy,
                    onClaim: _claim,
                  ),
                  const SizedBox(height: 24),
                  const AppFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Largura do cartão de cada nó e altura fixa do espaço que ele ocupa: com a
/// geometria fechada a serpentina é desenhada sem medir a árvore de widgets.
const _nodeWidth = 236.0;
const _nodeExtent = 196.0;
const _badgeSize = 40.0;

/// Deslocamento horizontal dos nós em ciclo: esquerda, meio, direita, meio.
const _laneShifts = [-0.7, 0.0, 0.7, 0.0];

double _laneShift(int index) => _laneShifts[index % _laneShifts.length];

class PassTrail extends StatelessWidget {
  const PassTrail({
    super.key,
    required this.tiers,
    required this.names,
    required this.points,
    required this.premiumUnlocked,
    required this.busy,
    required this.onClaim,
  });

  final List<Map> tiers;
  final Map<String, String> names;
  final int points;
  final bool premiumUnlocked;
  final bool busy;
  final void Function(int tier, String track) onClaim;

  double _dx(int index, double width) =>
      width / 2 + _laneShift(index) * math.max(0.0, (width - _nodeWidth) / 2);

  /// O tier 1 fica embaixo, então a linha sobe conforme o índice cresce. O
  /// conteúdo do nó é alinhado ao topo do próprio espaço, donde o centro do
  /// selo estar a meio do badge a partir dali.
  double _dy(int index) =>
      (tiers.length - 1 - index) * _nodeExtent + _badgeSize / 2;

  /// Ponto da trilha para uma posição fracionária entre tiers — é onde o
  /// corredor está conforme o XP.
  Offset centerAt(double index, double width) {
    if (index < 0) {
      // XP ainda abaixo do tier 1: o corredor espera embaixo do primeiro nó.
      return Offset(_dx(0, width), _dy(0) + 60);
    }
    final lower = index.floor();
    final fraction = index - lower;
    final start = Offset(_dx(lower, width), _dy(lower));
    if (fraction == 0 || lower + 1 >= tiers.length) return start;
    final end = Offset(_dx(lower + 1, width), _dy(lower + 1));
    return Offset(
      start.dx + (end.dx - start.dx) * fraction,
      start.dy + (end.dy - start.dy) * fraction,
    );
  }

  /// Índice fracionário do corredor: o último tier alcançado, mais a fatia do
  /// caminho até o próximo que o XP já cobriu.
  double get runnerIndex {
    if (tiers.isEmpty) return 0;
    var base = -1.0;
    for (var i = 0; i < tiers.length; i++) {
      if (points >= (tiers[i]['threshold'] as num).toInt()) base = i.toDouble();
    }
    final next = base + 1;
    if (next >= tiers.length) return tiers.length - 1.0;
    final fromThreshold = base < 0
        ? 0.0
        : (tiers[base.toInt()]['threshold'] as num).toInt();
    final toThreshold = (tiers[next.toInt()]['threshold'] as num).toInt();
    final span = toThreshold - fromThreshold;
    if (span <= 0) return base;
    return base + ((points - fromThreshold) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final count = tiers.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _nodeWidth;
        return CustomPaint(
          painter: _TrailPainter(trail: this, width: width),
          child: SizedBox(
            width: width,
            height: math.max(_nodeExtent, count * _nodeExtent),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < count; i++) _node(context, i, width),
                if (count > 0) _runner(width),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _node(BuildContext context, int index, double width) {
    return Positioned(
      left: _dx(index, width) - _nodeWidth / 2,
      top: _dy(index) - _badgeSize / 2,
      width: _nodeWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TierBadge(tier: tiers[index], premiumUnlocked: premiumUnlocked),
          const SizedBox(height: 6),
          _TierCard(
            tier: tiers[index],
            names: names,
            points: points,
            premiumUnlocked: premiumUnlocked,
            busy: busy,
            onClaim: onClaim,
          ),
        ],
      ),
    );
  }

  Widget _runner(double width) {
    final position = centerAt(runnerIndex, width);
    return Positioned(
      left: position.dx - 17,
      // Acima do ponto do caminho: embaixo cobriria o número do tier.
      top: position.dy - _badgeSize - 10,
      child: Semantics(
        label: 'Você aqui',
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC93C),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_run,
            size: 20,
            color: Color(0xFF1A0E08),
          ),
        ),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter({required this.trail, required this.width});

  final PassTrail trail;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final count = trail.tiers.length;
    if (count < 2) return;
    for (var i = 0; i < count - 1; i++) {
      final from = trail.centerAt(i.toDouble(), width);
      final to = trail.centerAt((i + 1).toDouble(), width);
      final reached = trail.tiers[i + 1]['unlocked'] == true;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(width / 2, (from.dy + to.dy) / 2, to.dx, to.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF4C1D95).withValues(
            alpha: reached ? 0.9 : 0.22,
          )
          ..strokeWidth = reached ? 8 : 5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.width != width ||
      old.trail.points != trail.points ||
      old.trail.tiers != trail.tiers;
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier, required this.premiumUnlocked});

  final Map tier;
  final bool premiumUnlocked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = tier['unlocked'] == true;
    // O nó só se esvazia quando tudo o que ele dá foi resgatado; sem premium
    // ativado a trilha premium não conta.
    final freeClaimed = tier['free']?['claimed'] == true;
    final premiumClaimed = tier['premium']?['claimed'] == true;
    final emptied =
        unlocked && freeClaimed && (!premiumUnlocked || premiumClaimed);
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: unlocked
            ? const Color(0xFF6D28D9)
            : scheme.surfaceContainerHighest,
        border: Border.all(
          color: unlocked ? const Color(0xFFFFC93C) : scheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Center(
        child: emptied
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : Text(
                '${tier['tier']}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: unlocked ? Colors.white : scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.names,
    required this.points,
    required this.premiumUnlocked,
    required this.busy,
    required this.onClaim,
  });

  final Map tier;
  final Map<String, String> names;
  final int points;
  final bool premiumUnlocked;
  final bool busy;
  final void Function(int tier, String track) onClaim;

  String _rewardLabel(Map? reward) {
    if (reward == null) return '—';
    final parts = <String>[];
    final coins = (reward['coins'] as num?)?.toInt() ?? 0;
    if (coins > 0) parts.add('+${fmt(coins)} 🪙');
    final itemId = '${reward['item_id'] ?? ''}';
    if (itemId.isNotEmpty) parts.add(names[itemId] ?? 'Exclusivo');
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = tier['unlocked'] == true;
    final free = tier['free'] as Map?;
    final premium = tier['premium'] as Map?;
    final tierNum = (tier['tier'] as num).toInt();
    final threshold = (tier['threshold'] as num).toInt();
    final muted = TextStyle(
      fontSize: 11,
      color: scheme.onSurfaceVariant,
    );
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      // Sem contorno próprio o tier alcançado ficava solto no fundo da tela:
      // a borda roxa é o que separa o nó já liberado do que ainda falta.
      color: unlocked ? scheme.surface : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unlocked ? const Color(0xFF6D28D9) : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tier $tierNum · ${fmt(threshold)} XP',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 2),
            if (!unlocked)
              Text(
                'Faltam ${fmt(math.max(0, threshold - points))} XP',
                style: muted,
              ),
            Text('Grátis: ${_rewardLabel(free)}', style: muted),
            Text('Premium: ${_rewardLabel(premium)}', style: muted),
            const SizedBox(height: 8),
            Row(
              children: [
                _ClaimButton(
                  label: 'Grátis',
                  state: !unlocked
                      ? _ClaimState.locked
                      : free?['claimed'] == true
                      ? _ClaimState.done
                      : _ClaimState.ready,
                  busy: busy,
                  onTap: () => onClaim(tierNum, 'free'),
                ),
                const SizedBox(width: 6),
                _ClaimButton(
                  label: 'Premium',
                  state: !unlocked
                      ? _ClaimState.locked
                      : !premiumUnlocked
                      ? _ClaimState.premium
                      : premium?['claimed'] == true
                      ? _ClaimState.done
                      : _ClaimState.ready,
                  busy: busy,
                  onTap: () => onClaim(tierNum, 'premium'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ClaimState { locked, ready, done, premium }

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({
    required this.label,
    required this.state,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final _ClaimState state;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _ClaimState.done:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check, size: 16, color: Color(0xFF16A34A)),
        );
      case _ClaimState.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.lock_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      case _ClaimState.premium:
        return OutlinedButton(
          onPressed: busy ? null : onTap,
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 14),
              const SizedBox(width: 2),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
      case _ClaimState.ready:
        return FilledButton(
          onPressed: busy ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        );
    }
  }
}
