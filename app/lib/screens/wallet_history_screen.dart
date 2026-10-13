import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import '../widgets/cosmetics.dart';
import '../widgets/runover_ui.dart';

/// Motivo do extrato em pt-BR. O servidor grava chaves internas
/// (`compra:avatar_corredor`, `passe:season:t3:cosmetic`), e id/chave
/// interna não aparece na UI: compra resolve pelo catálogo e o resto cai
/// num rótulo legível.
String walletReasonLabel(String reason, List<ShopItem> catalog) {
  final parts = reason.split(':');
  return switch (parts) {
    ['compra', final id] => findItem(catalog, id)?.name ?? 'Compra no mercado',
    ['passe', _, final tier, _] when tier.startsWith('t') =>
      'Recompensa do passe · nível ${tier.substring(1)}',
    ['passe', ...] => 'Compra do passe',
    ['distancia'] => 'Distância percorrida',
    ['conquista'] => 'Conquista de território',
    ['missao_diaria'] => 'Missão diária',
    ['streak'] => 'Sequência de dias',
    _ => 'Outro movimento',
  };
}

/// Um movimento do extrato, já lido do payload do `/shop/wallet`.
///
/// A transação malformada (registro legado sem `delta` numérico) é descartada
/// na leitura: uma linha quebrada não pode derrubar a tela inteira nem aparecer
/// como "Outro movimento" sem valor.
class _Entry {
  const _Entry({
    required this.reason,
    required this.delta,
    required this.when,
  });

  final String reason;
  final int delta;
  final DateTime? when;
}

class _Statement {
  const _Statement({required this.balance, required this.entries});

  final int balance;
  final List<_Entry> entries;
}

/// Um dia do extrato, na ordem em que veio (o servidor já devolve do mais
/// recente para o mais antigo).
class _DayGroup {
  const _DayGroup(this.day, this.items);

  final String day;
  final List<_Entry> items;
}

List<_DayGroup> _groupByDay(List<_Entry> entries) {
  final byDay = <String, List<_Entry>>{};
  for (final e in entries) {
    final label = e.when == null ? 'Sem data' : formatDayLabel(e.when!);
    byDay.putIfAbsent(label, () => []).add(e);
  }
  return [
    for (final day in byDay.entries) _DayGroup(day.key, day.value),
  ];
}

/// Extrato de dracmas: os movimentos que compõem o saldo do Mercado.
///
/// É a resposta do "de onde veio esse número?" sem pedir que a pessoa faça
/// conta: cada linha diz o motivo em pt-BR e o valor com sinal. O servidor
/// entrega os 50 mais recentes — a nota no pé diz isso em vez de deixar a
/// lista parecer o histórico completo.
class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  late Future<_Statement> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(context.read<AppState>().api);
  }

  Future<_Statement> _load(ApiClient api) async {
    final results = await Future.wait([api.getWallet(), api.getShopCatalog()]);
    final wallet = Map<String, dynamic>.from(results[0] as Map);
    final catalog = results[1] as List<ShopItem>;
    final entries = <_Entry>[];
    for (final t
        in (wallet['transactions'] as List? ?? const []).whereType<Map>()) {
      final delta = t['delta'];
      if (delta is! num) continue;
      entries.add(
        _Entry(
          reason: walletReasonLabel('${t['reason']}', catalog),
          delta: delta.toInt(),
          when: DateTime.tryParse('${t['created_at']}'),
        ),
      );
    }
    return _Statement(
      balance: (wallet['balance'] as num?)?.toInt() ?? 0,
      entries: entries,
    );
  }

  void _reload() {
    setState(() {
      _future = _load(context.read<AppState>().api);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de dracmas'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<_Statement>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: scheme.primary),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _Framed(
              child: ErrorBanner(
                message: 'Não foi possível carregar o extrato.',
                onRetry: _reload,
              ),
            );
          }
          final data = snapshot.data!;
          final groups = _groupByDay(data.entries);
          return CenteredContent(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _BalanceCard(balance: data.balance),
                if (groups.isEmpty) ...[
                  const SizedBox(height: 24),
                  const _EmptyBox(),
                ] else ...[
                  for (final group in groups) ...[
                    const SizedBox(height: 20),
                    SectionHeader(group.day),
                    const SizedBox(height: 12),
                    for (final entry in group.items) ...[
                      _EntryCard(entry: entry),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Mostrando os ${data.entries.length} movimentos mais '
                    'recentes.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A coluna central para os estados que não são lista (falha, vazio).
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CenteredContent(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: child,
    ),
  );
}

/// Saldo no topo do extrato: o número que as linhas abaixo explicam.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return GameCard(
      color: pal.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const DracmaCoin(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALDO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: pal.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatPoints(balance)} dracmas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: pal.heading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha do extrato: motivo à esquerda, valor com sinal à direita.
class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final gained = entry.delta >= 0;
    // O verde do kit é a tinta de "entrou dracma"; a saída é neutra de
    // propósito — vermelho é erro, e comprar não é.
    final ink = gained ? Pal.successInk(context) : pal.heading;
    return GameCard(
      color: pal.card,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: pal.heading,
                  ),
                ),
                if (entry.when != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formatClock(entry.when!),
                    style: TextStyle(fontSize: 11, color: pal.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${gained ? '+' : '−'}${formatPoints(entry.delta.abs())}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return GameCard(
      color: pal.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 40,
            color: pal.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum movimento ainda.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: pal.heading,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Corra para juntar as primeiras dracmas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: pal.muted),
          ),
        ],
      ),
    );
  }
}
