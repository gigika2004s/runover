import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import '../widgets/runover_ui.dart';

/// RF18/RN16 — UC "Receber Notificação".
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getNotifications();
  }

  Future<void> _open(NotificationEntry n) async {
    if (!n.isRead) {
      await context.read<AppState>().api.markNotificationRead(
        n.id,
      ); // "Marca notificação como lida"
      setState(() {
        _future = context.read<AppState>().api.getNotifications();
      });
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'conquista':
        return Icons.emoji_events;
      case 'perda':
        return Icons.trending_down;
      case 'nivel':
        return Icons.arrow_upward;
      case 'ranking':
        return Icons.leaderboard;
      case 'liga':
        return Icons.military_tech;
      default:
        return Icons.campaign;
    }
  }

  /// Tinta por tipo. Vem do `ColorScheme`, não de `RunoverColors.*`: a rota
  /// `#D9531F` e o território `#0E7F8F` foram desenhados para o fundo claro e
  /// somem sobre o painel escuro. O schema já resolve o par de cada brilho.
  Color _colorFor(String type, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'conquista':
        return scheme.secondary;
      case 'perda':
        return scheme.error;
      case 'nivel':
        return scheme.primary;
      case 'ranking':
        return scheme.secondary;
      case 'liga':
        return Pal.goldInk(context);
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: FutureBuilder<List<NotificationEntry>>(
        future: _future,
        builder: (context, snapshot) {
          final scheme = Theme.of(context).colorScheme;
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: scheme.primary),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Nenhuma notificação ainda.'));
          }
          return CenteredContent(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                return ListTile(
                  onTap: () => _open(n),
                  tileColor: n.isRead
                      ? null
                      : scheme.primary.withValues(alpha: 0.08),
                  leading: Icon(_iconFor(n.type), color: _colorFor(n.type, context)),
                  title: Text(
                    n.message,
                    style: TextStyle(
                      fontWeight: n.isRead
                          ? FontWeight.normal
                          : FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${n.createdAt.day}/${n.createdAt.month} às ${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
