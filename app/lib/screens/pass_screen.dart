import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../season_pass/backend.dart' show seasonFromStatus;
import '../state/app_state.dart';
import '../widgets/runover_ui.dart';
import 'season_pass_screen.dart';

/// Painel do Passe de Temporada na home: a temporada vigente, o nível, a barra
/// do XP que falta para o próximo nível e o botão que abre a trilha.
///
/// Os números vêm do `GET /pass` lido pelo mesmo conversor da tela da trilha
/// ([seasonFromStatus]), então painel e trilha nunca discordam. O catálogo da
/// loja não é buscado aqui: o cartão anuncia nível, prazo e as dracmas da
/// próxima recompensa.
class SeasonPanel extends StatefulWidget {
  const SeasonPanel({super.key});

  @override
  State<SeasonPanel> createState() => _SeasonPanelState();
}

class _SeasonPanelState extends State<SeasonPanel>
    with AccountWatcher<SeasonPanel> {
  late Future<Map<String, dynamic>> _future = _startLoad();

  @override
  bool get busy => false;

  @override
  void onAccountChanged() => _reload();

  Future<Map<String, dynamic>> _load() =>
      context.read<AppState>().api.getPassRunover();

  /// A home monta o painel numa lista preguiçosa: ele pode ser descartado
  /// antes da resposta chegar, e um `Future` sem listener denuncia o próprio
  /// erro como exceção não tratada.
  Future<Map<String, dynamic>> _startLoad() {
    final future = _load();
    future.then<void>((_) {}, onError: (Object _) {});
    return future;
  }

  void _reload() {
    markRevisionSeen();
    setState(() {
      _future = _startLoad();
    });
  }

  void _openTrail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SeasonPassScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Sem `CircularProgressIndicator`: a home é testada com
          // `pumpAndSettle`, e um giro indeterminado nunca assenta.
          return const _SeasonPanelFrame(
            child: Center(
              child: Text('Carregando o passe…', style: TextStyle(color: Colors.white)),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _SeasonPanelFrame(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Não foi possível carregar o passe.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                GameButton(
                  label: 'Tentar de novo',
                  compact: true,
                  ghost: true,
                  onPressed: _reload,
                ),
              ],
            ),
          );
        }
        return _SeasonPanelBody(
          status: snapshot.data!,
          onOpenTrail: _openTrail,
        );
      },
    );
  }
}

/// Casca do painel — o mesmo cartão índigo nos três estados — para o corpo não
/// repetir a decoração no "carregando" e no "falhou".
class _SeasonPanelFrame extends StatelessWidget {
  const _SeasonPanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return GameCard(
      color: pal.hud,
      borderColor: pal.border,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: SizedBox(height: 208, child: child),
    );
  }
}

class _SeasonPanelBody extends StatelessWidget {
  const _SeasonPanelBody({
    required this.status,
    required this.onOpenTrail,
  });

  final Map<String, dynamic> status;
  final VoidCallback onOpenTrail;

  /// Próximo tier ainda não liberado — é a recompensa que a linha anuncia.
  static Map? _nextTier(List<Map> tiers) {
    for (final tier in tiers) {
      if (tier['unlocked'] != true) return tier;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final season = seasonFromStatus(status, const {});
    final tiers = (status['tiers'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final free = _nextTier(tiers)?['free'] as Map?;
    final coins = (free?['coins'] as num?)?.toInt() ?? 0;
    final hasItem = '${free?['item_id'] ?? ''}'.isNotEmpty;
    final left = countdown(status['ends_at'] as String?);
    final rewardLine = [
      if (coins > 0) 'Próxima: +${formatPoints(coins)} dracmas',
      if (hasItem) 'com item exclusivo',
      if (season.pointsToNextLevel > 0)
        'faltam ${formatPoints(season.pointsToNextLevel)} XP'
      else
        'trilha completa',
    ].join(' · ');

    return GameCard(
      color: pal.hud,
      borderColor: pal.border,
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CharacterAvatar(RCharacter.hexi, size: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEMPORADA ${season.name.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Colors.white,
                        shadows: kTextShadow,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        'Nível ${season.currentLevel} de ${tiers.length}',
                        // O prazo entra no meio da frase: só o "T" inicial muda.
                        if (left.isNotEmpty) left.replaceFirst('T', 't'),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pal.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ChunkyProgress(value: season.levelProgress, height: 12),
          const SizedBox(height: 12),
          Row(
            children: [
              const DracmaCoin(size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rewardLine,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pal.muted,
                  ),
                ),
              ),
              // O selo só aparece com o passe ativo: sem ele não há nada a
              // anunciar, e um botão de compra aqui duplicaria a entrada que a
              // própria trilha já tem.
              if (season.hasPass) ...[
                const SizedBox(width: 10),
                const _PremiumPill(),
              ],
            ],
          ),
          const SizedBox(height: 14),
          GameButton(
            label: 'Ver a trilha',
            expand: true,
            big: true,
            background: Colors.white,
            foreground: Pal.purple,
            onPressed: onOpenTrail,
          ),
        ],
      ),
    );
  }
}

/// Selo dourado de "trilha premium ativa" na linha da próxima recompensa.
class _PremiumPill extends StatelessWidget {
  const _PremiumPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: const BoxDecoration(
      color: Pal.gold,
      borderRadius: BorderRadius.all(Radius.circular(8)),
      boxShadow: [
        BoxShadow(color: Color(0x59000000), offset: Offset(0, 2)),
      ],
    ),
    child: const Text(
      'Trilha premium ativa',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Color(0xFF3A2A00),
      ),
    ),
  );
}

/// Observa a conta mudando longe da tela e recarrega, deixando a revisão
/// pendurada enquanto uma operação própria está em voo.
mixin AccountWatcher<T extends StatefulWidget> on State<T> {
  AppState? _watched;
  int _seenRevision = 0;

  /// `true` enquanto uma operação da própria tela está em andamento.
  bool get busy;

  /// Trás o estado novo da conta para a tela.
  void onAccountChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (identical(state, _watched)) return;
    _watched?.removeListener(_onStateChanged);
    _watched = state;
    _seenRevision = state.profileRevision;
    state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _watched?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final state = _watched;
    if (state == null || state.profileRevision == _seenRevision) return;
    // Com a tela ocupada a revisão fica não consumida: se a própria operação
    // recarregar, ela alcança a revisão e o flush do fim não busca de novo; se
    // ela falhar, o mesmo flush assume a recarga em vez de mostrar o estado
    // anterior.
    if (busy) return;
    if (mounted) onAccountChanged();
  }

  /// Processa a mudança externa que chegou enquanto a tela estava ocupada.
  void flushAccountRefresh() {
    final state = _watched;
    if (state == null || state.profileRevision == _seenRevision) return;
    onAccountChanged();
  }

  /// Marca a revisão atual como consumida antes de recarregar.
  void markRevisionSeen() {
    final state = _watched;
    if (state != null) _seenRevision = state.profileRevision;
  }
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

String seasonLabel(String seasonId) {
  final parts = seasonId.split('-');
  if (parts.length != 2) return seasonId;
  final month = int.tryParse(parts[1]) ?? 0;
  if (month < 1 || month > 12) return seasonId;
  return '${_months[month]} de ${parts[0]}';
}

String countdown(String? endsAt) {
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
