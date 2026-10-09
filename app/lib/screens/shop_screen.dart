import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import '../widgets/cosmetics.dart';
import 'app_footer.dart';

/// Mercado interno: moedinhas, catálogo (via API), compra e equipamento.
/// Estilo Discord: molduras, efeitos, faixas, nomes, avatares e emoticons.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// Seções da biblioteca da loja (estilo Discord).
const _sections = [
  ('tudo', 'Tudo'),
  ('avatar', 'Decorações de avatar'),
  ('placas', 'Placas de Identificação'),
  ('effect', 'Efeitos de perfil'),
  ('frame', 'Molduras de Perfil'),
  ('bundle', 'Pacotes'),
  ('orbs', 'Disponíveis com Orbs'),
  ('parceria', 'Parcerias'),
];

/// Emoticons ficam dentro de "Tudo"/mural; têm aba própria? Não — entram
/// em "Tudo" e nos pacotes. (Filtro separado só poluiria as seções.)
bool _inSection(ShopItem item, String section, int balance) {
  return switch (section) {
    'tudo' => true,
    'avatar' => item.category == 'avatar',
    'placas' => item.category == 'banner' || item.category == 'name_style',
    'effect' => item.category == 'effect',
    'frame' => item.category == 'frame',
    'bundle' => item.category == 'bundle',
    // Orbs = moedinhas: o que dá para comprar com o saldo atual.
    'orbs' => item.price > 0 && item.price <= balance,
    'parceria' => item.payload['collection'] == 'parceria',
    _ => true,
  };
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<_ShopData> _future;
  String _section = 'tudo';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load(context.read<AppState>().api);
  }

  Future<_ShopData> _load(ApiClient api) async {
    final results = await Future.wait([
      api.getShopCatalog(),
      api.getInventory(),
      api.getWallet(),
    ]);
    return _ShopData(
      catalog: results[0] as List<ShopItem>,
      inventory: results[1] as Inventory,
      wallet: Map<String, dynamic>.from(results[2] as Map),
    );
  }

  void _reload() {
    setState(() => _future = _load(context.read<AppState>().api));
  }

  Future<void> _buy(ShopItem item, int balance) async {
    if (balance < item.price) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moedas insuficientes. Corra para ganhar mais!')),
      );
      return;
    }
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await app.api.purchaseItem(item.id);
      await app.refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} comprado!')),
      );
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _equip(ShopItem item, Inventory inventory) async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final equipped = inventory.isEquipped(item);
      await app.api.equipItem(item.category, equipped ? null : item.id);
      await app.refreshProfile();
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mercado')),
      body: CenteredContent(
        maxWidth: 1080,
        child: FutureBuilder<_ShopData>(
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
                    const Text('Não foi possível carregar o mercado.'),
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
            final balance = (data.wallet['balance'] as num).toInt();
            final items = data.catalog
                .where((i) => _inSection(i, _section, balance))
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _WalletCard(balance: balance, wallet: data.wallet),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (value, label) in _sections)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _section == value,
                            onSelected: (_) => setState(() => _section = value),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nada por aqui ainda — corra para juntar moedas!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                for (final item in items) ...[
                  _ItemCard(
                    item: item,
                    owned: data.inventory.owned.contains(item.id),
                    equipped: data.inventory.isEquipped(item),
                    busy: _busy,
                    subtitle: _bundleSubtitle(item, data.catalog),
                    onBuy: () => _buy(item, balance),
                    onEquip: () => _equip(item, data.inventory),
                  ),
                  const SizedBox(height: 10),
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

class _ShopData {
  const _ShopData({
    required this.catalog,
    required this.inventory,
    required this.wallet,
  });
  final List<ShopItem> catalog;
  final Inventory inventory;
  final Map<String, dynamic> wallet;
}

/// "Inclui: A, B e C" para pacotes; null nas demais categorias.
String? _bundleSubtitle(ShopItem item, List<ShopItem> catalog) {
  if (item.category != 'bundle') return null;
  final grants = (item.payload['grants'] as List? ?? const []).map((e) => '$e');
  final names = [
    for (final id in grants)
      catalog.where((c) => c.id == id).map((c) => c.name).firstOrNull ??
          id,
  ];
  if (names.isEmpty) return null;
  return 'Inclui: ${names.join(', ')}';
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.balance, required this.wallet});
  final int balance;
  final Map<String, dynamic> wallet;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final transactions = (wallet['transactions'] as List? ?? const [])
        .whereType<Map>()
        .take(3)
        .toList();
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFFC93C)),
                const SizedBox(width: 8),
                Text(
                  '$balance moedas',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Ganhe correndo: km + conquistas + missão diária + sequência.'),
            if (transactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final t in transactions)
                Text(
                  '${(t['delta'] as num) > 0 ? '+' : ''}${t['delta']} · ${t['reason']}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
    this.subtitle,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onEquip;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final free = item.price == 0;
    final isBundle = item.category == 'bundle';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Preview(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    free ? 'Grátis' : '${item.price} moedas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (equipped)
                    const Text(
                      'Equipado',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    )
                  else if (owned && isBundle)
                    const Text(
                      'Na coleção',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (!owned)
              FilledButton(
                onPressed: busy ? null : onBuy,
                child: Text(free ? 'Resgatar' : 'Comprar'),
              )
            else if (!isBundle &&
                (item.category != 'emoticon' || !equipped))
              OutlinedButton(
                onPressed: busy ? null : onEquip,
                child: Text(equipped ? 'Tirar' : 'Equipar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.item});
  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.category) {
      'avatar' => Builder(
        builder: (context) {
          final asset = galleryAvatarAsset(item);
          return FramedAvatar(
            radius: 22,
            image: asset == null ? null : AssetImage(asset),
            fallbackLetter: item.name.isEmpty ? '?' : item.name[0],
            avatarItem: item,
          );
        },
      ),
      'frame' => FramedAvatar(
        radius: 22,
        fallbackLetter: 'V',
        frame: item,
      ),
      'banner' => Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          gradient: bannerGradient(item),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      'name_style' => Text(
        'Nome',
        style: styledName(
          'Nome',
          item,
          const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      'effect' => Text(
        (item.payload['kind'] ?? 'sparkle') == 'fire' ? '🔥' : '✨',
        style: const TextStyle(fontSize: 28),
      ),
      'emoticon' => Text(
        ((item.payload['emoji'] as List?) ?? const ['🎽']).join(' '),
        style: const TextStyle(fontSize: 22),
      ),
      'bundle' => const Text('📦', style: TextStyle(fontSize: 28)),
      _ => const Icon(Icons.style_outlined),
    };
  }
}
