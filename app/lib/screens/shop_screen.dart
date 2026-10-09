import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/app_state.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getShop();
  }

  void _reload() =>
      setState(() => _future = context.read<AppState>().api.getShop());

  Future<void> _action(String id, String action) async {
    try {
      final api = context.read<AppState>().api;
      if (action == 'purchase') {
        await api.purchaseCosmetic(id);
      } else if (action == 'favorite') {
        await api.toggleFavoriteCosmetic(id);
      } else {
        await api.equipCosmetic(id);
      }
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loja RUNOVER')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final owned = {
            for (final id in (data['owned'] as List? ?? [])) '$id',
          };
          final favorites = {
            for (final id in (data['favorites'] as List? ?? [])) '$id',
          };
          final items = (data['items'] as List? ?? []).cast<Map>();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '🪙 ${data['balance'] ?? 0} moedas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final raw in items)
                Card(
                  child: ListTile(
                    leading: Icon(_icon(raw['kind'] as String)),
                    title: Text(raw['name'] as String),
                    subtitle: Text(
                      '${raw['description']}\n${raw['price']} moedas · ${raw['rarity']}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Favoritar',
                          icon: Icon(
                            favorites.contains(raw['id'])
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          onPressed: () =>
                              _action(raw['id'] as String, 'favorite'),
                        ),
                        if (owned.contains(raw['id']))
                          OutlinedButton(
                            onPressed: () =>
                                _action(raw['id'] as String, 'equip'),
                            child: const Text('Usar'),
                          )
                        else
                          FilledButton(
                            onPressed: () =>
                                _action(raw['id'] as String, 'purchase'),
                            child: const Text('Comprar'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _icon(String kind) => switch (kind) {
    'badge' => Icons.workspace_premium_outlined,
    'avatar_frame' => Icons.account_circle_outlined,
    'profile_effect' => Icons.auto_awesome_outlined,
    _ => Icons.text_fields,
  };
}
