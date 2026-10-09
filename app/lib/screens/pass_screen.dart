import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import 'app_footer.dart';

/// Pass Runover: temporada mensal movida a XP, com trilhas gratuita e
/// premium (desbloqueio em moedas). Sem resgate, a recompensa expira.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassData {
  const _PassData({required this.status, required this.names});

  final Map<String, dynamic> status;
  final Map<String, String> names;
}

const _months = [
  '',
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _seasonLabel(String seasonId) {
  final parts = seasonId.split('-');
  if (parts.length != 2) return seasonId;
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return seasonId;
  return '${_months[month]} de ${parts[0]}';
}

String _countdown(String? endsAt) {
  final end = DateTime.tryParse(endsAt ?? '');
  if (end == null) return '';
  final left = end.difference(DateTime.now().toUtc());
  if (left.isNegative) return 'Temporada encerrada';
  final days = left.inDays;
  final hours = left.inHours % 24;
  if (days > 0) return 'Termina em $days d $hours h';
  final minutes = left.inMinutes % 60;
  if (hours > 0) return 'Termina em $hours h $minutes min';
  return 'Termina em $minutes min';
}

String _fmt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

class _PassScreenState extends State<PassScreen> {
  late Future<_PassData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load(context.read<AppState>().api);
  }

  Future<_PassData> _load(ApiClient api) async {
    final results = await Future.wait([
      api.getPassRunover(),
      api.getShopCatalog(scope: 'pass'),
    ]);
    final catalog = results[1] as List<ShopItem>;
    return _PassData(
      status: results[0] as Map<String, dynamic>,
      names: {for (final c in catalog) c.id: c.name},
    );
  }

  void _reload() {
    setState(() {
      _future = _load(context.read<AppState>().api);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensa resgatada!')),
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          '${_fmt(price)} moedas.',
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pass Runover')),
      body: CenteredContent(
        maxWidth: 720,
        child: FutureBuilder<_PassData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _PassHero(
                  status: status,
                  busy: _busy,
                  onUnlock: () => _unlockPremium(
                    (status['premium_price_coins'] as num).toInt(),
                  ),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < tiers.length; i++) ...[
                  _TierRow(
                    tier: tiers[i],
                    names: data.names,
                    premiumUnlocked:
                        status['premium_unlocked'] == true,
                    busy: _busy,
                    onClaim: (track) => _claim(
                      (tiers[i]['tier'] as num).toInt(),
                      track,
                    ),
                  ),
                  if (i < tiers.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 24),
                const AppFooter(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cabeçalho: temporada, contagem regressiva, progresso e premium.
class _PassHero extends StatelessWidget {
  const _PassHero({
    required this.status,
    required this.busy,
    required this.onUnlock,
  });

  final Map<String, dynamic> status;
  final bool busy;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final points = (status['seasonal_points'] as num).toInt();
    final unlocked = (status['unlocked_tier'] as num).toInt();
    final premium = status['premium_unlocked'] == true;
    final tiers = (status['tiers'] as List? ?? const []).whereType<Map>();
    final next = tiers
        .where((t) => (t['unlocked'] as bool?) != true)
        .toList();
    final nextAt = next.isEmpty
        ? null
        : (next.first['threshold'] as num).toInt();
    final progress = nextAt == null ? 1.0 : (points / nextAt).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium,
                color: Color(0xFFFFC93C),
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PASS RUNOVER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Temporada ${_seasonLabel('${status['season_id']}')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(points)} XP · tier $unlocked de 30 · ${_countdown(status['ends_at'] as String?)}',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFFFFC93C),
              ),
            ),
          ),
          if (nextAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Faltam ${_fmt(nextAt - points)} XP para o tier ${unlocked + 1}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: premium
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Color(0xFF22C55E),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Trilha premium ativa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : FilledButton.icon(
                    onPressed: busy ? null : onUnlock,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: Text(
                      'Premium · ${_fmt((status['premium_price_coins'] as num).toInt())} moedas',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC93C),
                      foregroundColor: const Color(0xFF1A0E08),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Fileira do tier: selo, limiar, recompensas e botões de resgate.
class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.names,
    required this.premiumUnlocked,
    required this.busy,
    required this.onClaim,
  });

  final Map tier;
  final Map<String, String> names;
  final bool premiumUnlocked;
  final bool busy;
  final ValueChanged<String> onClaim;

  String _rewardLabel(Map? reward) {
    if (reward == null) return '—';
    final parts = <String>[];
    final coins = (reward['coins'] as num?)?.toInt() ?? 0;
    if (coins > 0) parts.add('+${_fmt(coins)} 🪙');
    final itemId = '${reward['item_id'] ?? ''}';
    if (itemId.isNotEmpty) parts.add(names[itemId] ?? 'Exclusivo');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = tier['unlocked'] == true;
    final free = tier['free'] as Map?;
    final premium = tier['premium'] as Map?;
    final freeClaimed = free?['claimed'] == true;
    final premiumClaimed = premium?['claimed'] == true;
    final tierNum = (tier['tier'] as num).toInt();
    final threshold = (tier['threshold'] as num).toInt();
    return Card(
      color: unlocked ? null : scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unlocked
                    ? const Color(0xFF6D28D9)
                    : scheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Text(
                  '$tierNum',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: unlocked
                        ? Colors.white
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fmt(threshold)} XP',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Grátis: ${_rewardLabel(free)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Premium: ${_rewardLabel(premium)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ClaimButton(
                  label: 'Grátis',
                  state: !unlocked
                      ? _ClaimState.locked
                      : freeClaimed
                          ? _ClaimState.done
                          : _ClaimState.ready,
                  busy: busy,
                  onTap: () => onClaim('free'),
                ),
                const SizedBox(height: 6),
                _ClaimButton(
                  label: 'Premium',
                  state: !unlocked
                      ? _ClaimState.locked
                      : !premiumUnlocked
                          ? _ClaimState.premium
                          : premiumClaimed
                              ? _ClaimState.done
                              : _ClaimState.ready,
                  busy: busy,
                  onTap: () => onClaim('premium'),
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
          child: const Icon(
            Icons.check,
            size: 16,
            color: Color(0xFF16A34A),
          ),
        );
      case _ClaimState.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
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
