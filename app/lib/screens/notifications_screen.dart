import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../widgets/centered_content.dart';
import '../widgets/runover_ui.dart';

/// RF18/RN16 — UC "Receber Notificação".
///
/// A caixa é a do servidor: `GET /notifications` devolve tudo, mais recente
/// primeiro, e o único toque que escreve é `PATCH /notifications/{id}/read`.
/// Não existe "marcar todas como lidas" — sem rota própria na API, o botão
/// seria decorativo.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationEntry>> _future;

  /// A leitura em andamento vale para a tela toda: enquanto uma chamada anda,
  /// um segundo toque — no botão de atualizar ou em outro cartão — só empilharia
  /// escrita e releitura, sem acrescentar nada.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _read();
  }

  Future<List<NotificationEntry>> _read() =>
      context.read<AppState>().api.getNotifications();

  /// Relê a caixa inteira — é o que o resgate de uma leitura não lida faz
  /// também, para a tela continuar desenhando o servidor, não o toque.
  Future<void> _reload() async {
    final next = _read();
    setState(() {
      _future = next;
      _busy = true;
    });
    // O erro pertence ao `FutureBuilder`, que é quem mostra o cartão de falha.
    try {
      await next;
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _markRead(NotificationEntry n) async {
    // Um toque por vez, e ele vale para a caixa inteira: a leitura em andamento
    // já vai reler a tela, então um segundo PATCH só escreveria de novo o que o
    // primeiro já escreveu — e o `_busy` abaixo devolve o botão quando acaba.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().api.markNotificationRead(
        n.id,
      ); // "Marca notificação como lida"
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível marcar a notificação como lida.'),
          ),
        );
      }
      return;
    }
    // `_reload` é quem desliga o `_busy` no fim, inclusive na falha da releitura.
    await _reload();
  }

  /// Avisos do mesmo dia ficam sob uma única etiqueta. O servidor já manda o
  /// mais recente primeiro, então a ordem em que aparecem é a ordem da tela.
  List<_DayGroup> _groupByDay(List<NotificationEntry> items) {
    // A chave é o dia completo, e a etiqueta é só o título: `formatDayLabel`
    // omite o ano, então um "8 JAN" de 2025 e outro de 2026 não podem virar o
    // mesmo grupo. O mapa preserva a ordem de entrada — a do servidor.
    final days = <DateTime, List<NotificationEntry>>{};
    for (final n in items) {
      final local = n.createdAt.toLocal();
      days
          .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
          .add(n);
    }
    return [
      for (final day in days.entries)
        _DayGroup(formatDayLabel(day.key), day.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: scheme.primary),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            // Falha de leitura tem cara e botão: spinner girando para sempre
            // não diz à pessoa que a caixa não veio.
            return _Framed(
              child: ErrorBanner(
                message: 'Não foi possível carregar suas notificações.',
                onRetry: _reload,
              ),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return _Framed(child: const _EmptyBox());
          }
          final groups = _groupByDay(items);
          return CenteredContent(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(group.day),
                    const SizedBox(height: 12),
                    for (final n in group.items) ...[
                      _NotificationCard(entry: n, onOpen: () => _markRead(n)),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
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
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: child,
    ),
  );
}

/// Um dia da caixa: a etiqueta é o que a pessoa lê, os cartões vêm embaixo.
class _DayGroup {
  const _DayGroup(this.day, this.items);

  final String day;
  final List<NotificationEntry> items;
}

/// O cartão de um aviso: emblema do tipo, a frase do servidor e a hora.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.entry, required this.onOpen});

  final NotificationEntry entry;
  final VoidCallback onOpen;

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
      case 'equipe':
        return Icons.groups;
      default:
        return Icons.campaign;
    }
  }

  /// Fundo do emblema. Vem do `ColorScheme`, não de `RunoverColors.*`: os
  /// acentos fixos foram desenhados para o painel escuro do mock e um deles
  /// sobre o cartão claro daria um ícone invisível. A tinta do ícone sai de
  /// [inkOnAccent], que resolve o contraste dos dois lados.
  Color _fillFor(String type, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'conquista':
        return Pal.gold;
      case 'perda':
        return scheme.error;
      case 'nivel':
        return scheme.primary;
      case 'ranking':
        return scheme.secondary;
      case 'liga':
        return Pal.purple;
      case 'equipe':
        return Pal.team;
      default:
        return scheme.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final scheme = Theme.of(context).colorScheme;
    final unread = !entry.isRead;
    final fill = _fillFor(entry.type, context);
    return GameCard(
      color: pal.card,
      padding: const EdgeInsets.all(14),
      // O único toque com lógica é o de marcar como lida; o cartão já lido não
      // tem o que escrever no servidor e fica fechado.
      onTap: unread ? onOpen : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
            child: Icon(
              _iconFor(entry.type),
              color: inkOnAccent(fill),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: TextStyle(
                    color: pal.heading,
                    fontSize: 14,
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                // O dia já está na etiqueta do grupo; aqui fica só a hora,
                // montada pelo helper — `'$hour:$minute'` na mão imprime `9:5`.
                Text(
                  formatClock(entry.createdAt),
                  style: TextStyle(color: pal.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (unread)
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Semantics(
                // `container: true` mantém o ponto como nó próprio. Sem ele o
                // rótulo é engolido pelo nó do cartão, e quem usa leitor de
                // tela ouve a frase do aviso sem saber que ela não foi lida.
                container: true,
                label: 'Não lida',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Caixa vazia: o que a pessoa pode esperar receber, sem promessa de modo.
class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return GameCard(
      color: pal.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none, color: pal.muted, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nenhuma notificação ainda.',
                  style: TextStyle(
                    color: pal.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Conquistas, perdas de território, níveis e avisos da equipe '
            'chegam aqui assim que acontecerem.',
            style: TextStyle(color: pal.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
