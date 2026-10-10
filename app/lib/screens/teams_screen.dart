import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/centered_content.dart';
import '../widgets/cosmetics.dart';
import '../widgets/level_badge.dart';
import '../widgets/team_settings_drawer.dart';
import 'app_footer.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';

/// Uma equipe conta como "nova" nos primeiros 7 dias. Comparação em UTC dos
/// dois lados para não depender do fuso do aparelho nem do formato (com ou
/// sem `Z`) enviado pelo backend.
bool isNewTeam(TeamSummary team) {
  final created = team.createdAt;
  if (created == null) return false;
  return DateTime.now().toUtc().difference(created.toUtc()).inDays < 7;
}

/// RF16/RN14/RN15 — UC10 (Criar/participar de equipe).
class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  TeamDetail? _myTeam;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final team = await context.read<AppState>().api.getMyTeam();
      setState(() => _myTeam = team);
    } on ApiException {
      setState(() => _myTeam = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _myTeam;
    // Sem wrapper de Theme aqui: a tela herda o tema claro/escuro do app
    // (MaterialApp) para acompanhar a troca em tempo real.
    return Scaffold(
      appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined),
              SizedBox(width: 8),
              Text('Equipe'),
            ],
          ),
          actions: [
            if (team != null && team.isAdmin)
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Configurações da equipe',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
          ],
        ),
        endDrawer: team != null && team.isAdmin
            ? TeamSettingsDrawer(team: team, onChanged: _load)
            : null,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: RunoverColors.route),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: _myTeam != null
                    ? _MyTeamView(team: _myTeam!, onChanged: _load)
                    : _JoinOrCreateView(onChanged: _load, error: _error),
              ),
    );
  }
}

/// Arte estável por equipe a partir da galeria de avatares (sem campo
/// de imagem na API): o id define qual asset ilustra o card.
/// Usa FNV-1a porque `String.hashCode` varia entre execuções/plataformas.
String teamCardAsset(String teamId) {
  var hash = 0x811c9dc5;
  for (final unit in teamId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return presetAvatars[hash % presetAvatars.length].asset;
}

class _MyTeamView extends StatelessWidget {
  final TeamDetail team;
  final VoidCallback onChanged;
  const _MyTeamView({required this.team, required this.onChanged});

  Future<void> _leave(BuildContext context) async {
    final myUsername = context.read<AppState>().profile?.username;
    final others = team.members
        .where((m) => m.username != myUsername)
        .toList();
    if (team.isOwner && others.isNotEmpty) {
      await _leaveAsOwner(context, others);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair da equipe?'),
        content: Text('Você vai deixar de fazer parte de ${team.name}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _act(context, () async {
        await context.read<AppState>().api.leaveTeam();
      });
    }
  }

  /// Dono com membros: escolhe o sucessor ou dissolve a equipe para sair.
  Future<void> _leaveAsOwner(
    BuildContext context,
    List<TeamMemberInfo> others,
  ) async {
    String? successor = others.first.username;
    var dissolve = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          title: const Text('Passar a posse ou dissolver?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Você é dono de ${team.name}. Escolha um sucessor '
                'ou dissolva a equipe para sair.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: dissolve ? null : successor,
                decoration: const InputDecoration(
                  labelText: 'Sucessor',
                ),
                items: [
                  for (final m in others)
                    DropdownMenuItem(
                      value: m.username,
                      child: Text('@${m.username}'),
                    ),
                ],
                onChanged: (v) => setSheetState(() {
                  successor = v;
                  dissolve = false;
                }),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dissolver a equipe'),
                subtitle: const Text(
                  'Libera territórios e apaga a loja da equipe.',
                ),
                value: dissolve,
                onChanged: (v) =>
                    setSheetState(() => dissolve = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: dissolve
                  ? FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(ctx).colorScheme.error,
                    )
                  : null,
              child: Text(dissolve ? 'Dissolver e sair' : 'Transferir e sair'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _act(context, () async {
      final api = context.read<AppState>().api;
      if (dissolve) {
        await api.leaveTeam(dissolve: true);
      } else if (successor != null) {
        await api.leaveTeam(successorUsername: successor);
      }
    });
  }

  Future<void> _act(BuildContext context, Future<void> Function() call) async {
    try {
      await call();
      onChanged();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = team.zoneCapacity;
    return CenteredContent(
      maxWidth: 1500,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          _TeamIdentity(team: team),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = _statsRow(context, slots);
              final base = _TeamBaseCard(team: team);
              final progress = _TeamProgressCard(team: team);
              final members = _TeamMembersCard(team: team, onAct: _act);
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stats,
                    const SizedBox(height: 12),
                    base,
                    const SizedBox(height: 12),
                    progress,
                    const SizedBox(height: 12),
                    members,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [stats, const SizedBox(height: 12), base],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [progress, const SizedBox(height: 12), members],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _leave(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sair da equipe'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const _BrowseTeamsScreen(),
              ),
            ),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Ver outras equipes'),
          ),
          const SizedBox(height: 24),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _statsRow(BuildContext context, int slots) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Pontos',
            value: '${team.totalScore}',
            icon: Icons.bolt,
            iconColor: RunoverColors.route,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HistoryScreen(
                  title: 'Pontos de ${team.name}',
                  loader: () =>
                      context.read<AppState>().api.getTeamHistory(team.id),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Zonas conquistadas',
            value: '${math.min(team.territoriesCount, slots)} / $slots',
            icon: Icons.map_outlined,
            iconColor: RunoverColors.territory,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _TeamZonesScreen(team: team),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho do painel: arte da equipe, nome, autor e o selo de nível.
class _TeamIdentity extends StatelessWidget {
  const _TeamIdentity({required this.team});

  final TeamDetail team;

  @override
  Widget build(BuildContext context) {
    final photoImage = profileImageProvider(team.photoUrl);
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: RunoverColors.territory.withValues(alpha: 0.15),
          foregroundImage: photoImage,
          onForegroundImageError: photoImage == null ? null : (_, _) {},
          child: Text(
            team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: RunoverColors.territory,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          team.name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          'Criada por @${team.creatorUsername}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        LevelBadge(level: team.level),
      ],
    );
  }
}

/// Voltas de hexágono necessárias para desenhar `capacity` células. O
/// servidor publica a capacidade; daqui só sai geometria.
int _baseRingsForCapacity(int capacity) {
  var rings = 1;
  while (1 + 3 * rings * (rings + 1) < capacity && rings < 6) {
    rings++;
  }
  return rings;
}

/// Pontos axiais (q, r) de um hexágono de `rings` voltas, do centro para fora
/// e depois no sentido horário.
List<Offset> _hexCells(int rings) {
  final cells = <Offset>[];
  for (var q = -rings; q <= rings; q++) {
    for (var r = math.max(-rings, -q - rings);
        r <= math.min(rings, -q + rings);
        r++) {
      cells.add(Offset(q.toDouble(), r.toDouble()));
    }
  }
  cells.sort((a, b) {
    final distance = _hexDistance(a).compareTo(_hexDistance(b));
    if (distance != 0) return distance;
    return math
        .atan2(a.dy, a.dx)
        .compareTo(math.atan2(b.dy, b.dx));
  });
  return cells;
}

double _hexDistance(Offset cell) {
  final q = cell.dx, r = cell.dy;
  return (q.abs() + r.abs() + (q + r).abs()) / 2;
}

/// A base vista de cima: uma célula por território em posse da equipe, do
/// centro para fora, na ordem em que foram conquistados.
class _TeamBaseCard extends StatelessWidget {
  const _TeamBaseCard({required this.team});

  final TeamDetail team;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rings = _baseRingsForCapacity(team.zoneCapacity);
    // O servidor define quantas células existem; o anel só empresta a forma.
    final cells = _hexCells(rings).take(team.zoneCapacity).toList();
    // A posse atual vem do servidor; perder um território apaga a célula.
    final zones = team.territories.take(cells.length).toList();
    // Célula de 56px enquanto couber; uma base de 4 voltas transbordaria.
    final hexWidth = math.min(56.0, 340.0 / (1 + 1.5 * rings));
    final hexHeight = hexWidth * math.sqrt(3) / 2;
    final originX = hexWidth / 2 + 0.75 * hexWidth * rings;
    final originY = hexHeight / 2 + hexHeight * rings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Base da equipe',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: originX * 2,
                height: originY * 2,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < cells.length; i++)
                      Positioned(
                        left: originX +
                            0.75 * hexWidth * cells[i].dx -
                            hexWidth / 2,
                        top: originY +
                            hexHeight *
                                (cells[i].dy + cells[i].dx / 2) -
                            hexHeight / 2,
                        child: _HexSlot(
                          width: hexWidth,
                          height: hexHeight,
                          zone: i < zones.length ? zones[i] : null,
                          onTap: () => _showZone(context, i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                zones.isEmpty
                    ? 'Zona 1: conquiste um território no mapa para acendê-la'
                    : 'Toque em uma zona para ver o território que a acende',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A célula ocupada mostra o território real por trás dela; a vazia explica
  /// o que falta acendê-la. Nenhuma das duas inventa uma conquista própria.
  Future<void> _showZone(BuildContext context, int index) async {
    final zone = index < team.territories.length
        ? team.territories[index]
        : null;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zona ${index + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (zone != null) ...[
              Text(
                zone.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: RunoverColors.route,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${zone.points} pts · conquistado em ${_zoneDate(zone.conqueredAt)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A célula pertence enquanto a posse for da equipe: se outro '
                'corredor fechar o laço por cima, o território muda de dono e '
                'a zona se apaga.',
              ),
            ] else ...[
              const Text('Livre — nada ocupa esta célula ainda.'),
              const SizedBox(height: 10),
              const Text(
                'Território se conquista correndo: abra o Mapa, saia daqui e '
                'feche um laço com o trajeto gravado. A tolerância para fechar '
                'vem da precisão do GPS em cada ponto, e uma pausa só custa a '
                'zona se você retomar a mais de 100 m do ponto parado.',
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _zoneDate(DateTime d) {
  final local = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

/// Uma célula hexagonal da base: ocupada por um território ou livre.
class _HexSlot extends StatelessWidget {
  const _HexSlot({
    required this.width,
    required this.height,
    required this.zone,
    required this.onTap,
  });

  final double width;
  final double height;
  final TeamTerritoryInfo? zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conquered = zone != null;
    final accent = conquered ? RunoverColors.route : scheme.onSurfaceVariant;
    return Tooltip(
      message: conquered
          ? 'Zona: ${zone!.name}'
          : 'Zona livre: conquiste um território no mapa',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _HexagonPainter(
              fill: conquered
                  ? RunoverColors.route.withValues(alpha: 0.18)
                  : scheme.onSurface.withValues(alpha: 0.04),
              stroke: conquered
                  ? RunoverColors.route
                  : scheme.outlineVariant.withValues(alpha: 0.7),
            ),
            child: Center(
              child: Icon(
                conquered ? Icons.push_pin : Icons.add,
                size: 18,
                color: accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  const _HexagonPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i;
      final point = Offset(
        size.width / 2 + size.width / 2 * math.cos(angle),
        size.height / 2 + size.height / 2 * math.sin(angle),
      );
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = stroke,
    );
  }

  @override
  bool shouldRepaint(_HexagonPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// Progresso da equipe até o próximo nível e o que ele libera.
class _TeamProgressCard extends StatelessWidget {
  const _TeamProgressCard({required this.team});

  final TeamDetail team;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nextThreshold = team.totalScore + team.pointsToNextLevel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Progresso da equipe',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${team.totalScore} / $nextThreshold pts',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TeamProgressBar(progress: team.levelProgress),
            const SizedBox(height: 8),
            Text(
              'Faltam ${team.pointsToNextLevel} pts para o nível '
              '${team.level + 1}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  _IconTile(icon: Icons.add, color: RunoverColors.route),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Próximo nível',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'O nível ${team.level + 1} libera mais zonas na base',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamProgressBar extends StatelessWidget {
  const _TeamProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 10,
        color: scheme.onSurface.withValues(alpha: 0.08),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [RunoverColors.route, RunoverColors.routeDark],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Membros visíveis, papel de cada um e como entrar na equipe.
class _TeamMembersCard extends StatelessWidget {
  const _TeamMembersCard({required this.team, required this.onAct});

  final TeamDetail team;
  final Future<void> Function(BuildContext, Future<void> Function()) onAct;

  static const _visible = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = team.members.take(_visible).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Membros (${team.memberCount})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (team.members.length > _visible)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _AllMembersScreen(team: team, onAct: onAct),
                      ),
                    ),
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            for (final member in shown)
              _MemberRow(team: team, member: member, onAct: onAct),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: () => _explainInvite(context),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Convidar amigos'),
            ),
            if (team.isOwner)
              Text(
                'Pedidos de entrada aparecem em Configurações da equipe.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Não há convite pelo app: quem entra é aprovado pelo criador/admin.
  Future<void> _explainInvite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: team.name));
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chamar para ${team.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'O nome da equipe foi copiado. Peça para procurarem por ele na '
              'aba Equipe e enviarem o pedido de entrada; quem cria ou '
              'administra aprova em Configurações da equipe.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
    messenger.showSnackBar(const SnackBar(content: Text('Nome copiado.')));
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.team, required this.member, required this.onAct});

  final TeamDetail team;
  final TeamMemberInfo member;
  final Future<void> Function(BuildContext, Future<void> Function()) onAct;

  @override
  Widget build(BuildContext context) {
    final isCreator = member.username == team.creatorUsername;
    final photo = profileImageProvider(member.photoUrl);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // O mesmo perfil público que o ranking abre.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(username: member.username),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: RunoverColors.route.withValues(alpha: 0.18),
                foregroundImage: photo,
                onForegroundImageError: photo == null ? null : (_, _) {},
                child: Text(
                  member.username.isNotEmpty
                      ? member.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: RunoverColors.route,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '@${member.username}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (isCreator)
                const _RoleChip(label: 'Criador', color: Color(0xFFE3A008))
              else if (member.isAdmin)
                const _RoleChip(label: 'Admin', color: RunoverColors.territory),
              if (team.isOwner && !isCreator)
                PopupMenuButton<String>(
                  tooltip: 'Ações de admin',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => onAct(
                    context,
                    action == 'promote'
                        ? () => context
                              .read<AppState>()
                              .api
                              .promoteAdmin(team.id, member.username)
                        : () => context
                              .read<AppState>()
                              .api
                              .demoteAdmin(team.id, member.username),
                  ),
                  itemBuilder: (_) => [
                    if (!member.isAdmin)
                      const PopupMenuItem(
                        value: 'promote',
                        child: Text('Tornar admin'),
                      )
                    else
                      const PopupMenuItem(
                        value: 'demote',
                        child: Text('Remover admin'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.16),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Lista completa de membros para quando o card não dá conta.
class _AllMembersScreen extends StatelessWidget {
  const _AllMembersScreen({required this.team, required this.onAct});

  final TeamDetail team;
  final Future<void> Function(BuildContext, Future<void> Function()) onAct;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Membros de ${team.name}')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final member in team.members)
            _MemberRow(team: team, member: member, onAct: onAct),
        ],
      ),
    );
  }
}

/// As zonas acesas na base, em lista rolável: o mesmo dado que acende os
/// hexágonos, agora com histórico e valor de cada um.
class _TeamZonesScreen extends StatelessWidget {
  const _TeamZonesScreen({required this.team});

  final TeamDetail team;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final zones = team.territories;
    return Scaffold(
      appBar: AppBar(title: Text('Zonas de ${team.name}')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            zones.isEmpty
                ? 'Nenhuma das ${team.zoneCapacity} células da base está acesa.'
                : '${zones.length} de ${team.zoneCapacity} células acesas, da '
                      'conquista mais antiga para a mais nova.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (zones.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Território se conquista correndo: abra o Mapa, feche um '
                  'laço com o trajeto gravado e a primeira célula da base '
                  'acende.',
                ),
              ),
            )
          else
            for (var i = 0; i < zones.length; i++)
              Card(
                child: ListTile(
                  leading: _IconTile(
                    icon: Icons.push_pin,
                    color: RunoverColors.route,
                  ),
                  title: Text('Zona ${i + 1} · ${zones[i].name}'),
                  subtitle: Text(
                    '${zones[i].points} pts · conquistado em '
                    '${_zoneDate(zones[i].conqueredAt)}',
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          child: Row(
            children: [
              _IconTile(icon: icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de equipe com arte de fundo e véu escuro para legibilidade.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.pending,
    required this.onJoin,
    this.frame,
    this.nameStyle,
  });

  final TeamSummary team;
  final bool pending;
  final VoidCallback onJoin;
  final ShopItem? frame;
  final ShopItem? nameStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = [
      const Color(0xFF3DDBB0),
      const Color(0xFF8B7CFF),
      const Color(0xFFFFC93C),
      const Color(0xFFFF7F4D),
    ];
    var hash = 0x811c9dc5;
    for (final unit in team.id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    final accent = colors[hash % colors.length];
    final isNew = isNewTeam(team);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final details = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    team.name,
                    style: styledName(
                      team.name,
                      nameStyle,
                      TextStyle(
                        color: scheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isNew) _teamTag('Nova', const Color(0xFF8B7CFF)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Criada por @${team.creatorUsername}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _teamStat(
                    context,
                    '${team.memberCount} ${team.memberCount == 1 ? 'membro' : 'membros'}',
                  ),
                  _teamStat(
                    context,
                    team.territoriesCount == 0
                        ? 'Seja o primeiro'
                        : '${team.territoriesCount} zonas',
                  ),
                ],
              ),
            ],
          ),
        );
        final join = Semantics(
          button: !pending,
          container: true,
          excludeSemantics: true,
          label: pending
              ? 'Pedido pendente em ${team.name}'
              : 'Solicitar entrada na equipe ${team.name}',
          child: OutlinedButton(
            key: Key('team-join-${team.id}'),
            onPressed: pending ? null : onJoin,
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(pending ? 'Aguardando aprovação' : 'Solicitar entrada'),
          ),
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF0A0B10)
                    : Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _teamAvatar(team, accent),
                        const SizedBox(width: 16),
                        details,
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: join),
                  ],
                )
              : Row(
                  children: [
                    _teamAvatar(team, accent),
                    const SizedBox(width: 24),
                    details,
                    const SizedBox(width: 16),
                    join,
                  ],
                ),
        );
      },
    );
  }

  Widget _teamAvatar(TeamSummary team, Color accent) {
    final photo = profileImageProvider(team.photoUrl);
    return FramedAvatar(
      radius: 40,
      image: photo ?? AssetImage(teamCardAsset(team.id)),
      fallbackLetter: team.name.isNotEmpty
          ? team.name[0].toUpperCase()
          : '?',
      frame: frame,
    );
  }

  Widget _teamTag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF17131A),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _teamStat(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Vitrine de outras equipes para quem já tem equipe: ver pode, entrar
/// só depois de sair da atual (o servidor barra com 400).
class _BrowseTeamsScreen extends StatelessWidget {
  const _BrowseTeamsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outras equipes')),
      body: _JoinOrCreateView(browseOnly: true, error: null, onChanged: () {}),
    );
  }
}

class _JoinOrCreateView extends StatefulWidget {
  final VoidCallback onChanged;
  final String? error;
  final bool browseOnly;
  const _JoinOrCreateView({
    required this.onChanged,
    required this.error,
    this.browseOnly = false,
  });

  @override
  State<_JoinOrCreateView> createState() => _JoinOrCreateViewState();
}

class _JoinOrCreateViewState extends State<_JoinOrCreateView> {
  late Future<List<TeamSummary>> _teamsFuture;
  List<ShopItem> _catalog = const [];
  final _requested = <String>{};
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final api = context.read<AppState>().api;
    _teamsFuture = api.listTeams();
    api.getShopCatalog().then((catalog) {
      if (!mounted) return;
      setState(() => _catalog = catalog);
    }).ignore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createTeam() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Criar equipe'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nome da equipe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(nameCtrl.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await context.read<AppState>().api.createTeam(name);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _join(TeamSummary team) async {
    if (widget.browseOnly) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saia da sua equipe atual para participar de outra.'),
        ),
      );
      return;
    }
    try {
      await context.read<AppState>().api.joinTeam(team.id);
      if (mounted) setState(() => _requested.add(team.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Pedido duplicado: já está aguardando aprovação.
      if (e.statusCode == 409) {
        setState(() => _requested.add(team.id));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CenteredContent(
      maxWidth: 1500,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 18, 32, 28),
        children: [
          if (widget.error != null)
            _infoCard('Não foi possível carregar sua equipe. ${widget.error}'),
          if (widget.browseOnly)
            _infoCard(
              'Você já está em uma equipe. Para participar de outra, '
              'saia da atual primeiro.',
            ),
          if (!widget.browseOnly) _createBanner(),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar equipe pelo nome',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              _filterChip('all', 'Todas'),
              _filterChip('new', 'Novas'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'EQUIPES DISPONÍVEIS',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 17,
              letterSpacing: .6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<TeamSummary>>(
            future: _teamsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: RunoverColors.route,
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    _infoCard(
                      'Não foi possível carregar as equipes disponíveis.',
                    ),
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _teamsFuture = context
                            .read<AppState>()
                            .api
                            .listTeams(),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar de novo'),
                    ),
                  ],
                );
              }
              final query = _searchController.text.trim().toLowerCase();
              var teams = snapshot.data ?? const <TeamSummary>[];
              if (query.isNotEmpty) {
                teams = teams
                    .where((team) => team.name.toLowerCase().contains(query))
                    .toList();
              }
              if (_filter == 'new') {
                teams = teams.where(isNewTeam).toList();
              }
              if (teams.isEmpty) {
                final message = query.isNotEmpty
                    ? 'Nenhuma equipe corresponde à busca.'
                    : _filter == 'new'
                    ? 'Nenhuma equipe nova nesta semana.'
                    : 'Nenhuma equipe criada ainda.';
                return _infoCard(message);
              }
              return Column(
                children: teams
                    .map(
                      (t) => _TeamCard(
                        team: t,
                        pending: _requested.contains(t.id),
                        frame: findItem(_catalog, t.equippedFrame),
                        nameStyle: findItem(_catalog, t.equippedNameStyle),
                        onJoin: () => _join(t),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _createBanner() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const purple = Color(0xFF8B7CFF);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2240) : const Color(0xFFE9E6FF),
        border: Border.all(color: purple, width: 1.5),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF0A0B10)
                : Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: .15),
              border: Border.all(color: purple),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.groups_outlined,
              color: isDark ? const Color(0xFFC9C2FF) : purple,
              size: 38,
            ),
          );
          final copy = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Corra em grupo, domine mais',
                  style: TextStyle(
                    color: isDark ? Colors.white : scheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Você ainda não tem equipe. Crie a sua ou entre em uma para conquistar territórios juntos.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFD9D4FF)
                        : scheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        final button = FilledButton.icon(
          onPressed: _createTeam,
          icon: const Icon(Icons.add),
          label: const Text('Criar equipe'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF7F4D),
            foregroundColor: const Color(0xFF28140B),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
        );
        return constraints.maxWidth < 650
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [icon, const SizedBox(width: 16), copy]),
                  const SizedBox(height: 16),
                  button,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: 24),
                  copy,
                  const SizedBox(width: 20),
                  button,
                ],
              );
      },
    ),
    );
  }

  Widget _filterChip(String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      backgroundColor: scheme.surface,
      labelStyle: TextStyle(
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      side: BorderSide(
        color: selected ? scheme.primary : Colors.transparent,
      ),
      shape: const StadiumBorder(),
    );
  }

  Widget _infoCard(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
    );
  }
}
