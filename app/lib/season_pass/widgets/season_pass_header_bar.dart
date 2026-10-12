import 'package:flutter/material.dart';

import '../../format.dart';
import '../../widgets/runover_ui.dart';
import '../palette.dart';

/// Barra do topo do Passe de Temporada: o mascote, o nome da temporada, a
/// contagem regressiva e o saldo de dracmas.
///
/// É o cartão de abertura da tela, então ele carrega a gradiente laranja→rosa
/// do mock e texto branco: a temporada precisa parecer um evento, não mais um
/// card cinza da lista. O nome vem inteiro na linha do título — "TEMPORADA DE
/// OUTUBRO DE 2026" — porque é o nome que o jogador procura, não um rótulo.
///
/// O saldo ([dracmas]) vem do perfil e só existe quando a tela está ligada ao
/// backend; em modo controlado (demonstração e testes) o pill é omitido em vez
/// de mostrar um número inventado.
class SeasonPassHeaderBar extends StatelessWidget {
  const SeasonPassHeaderBar({
    super.key,
    required this.seasonName,
    required this.remaining,
    required this.hasPass,
    this.dracmas,
  });

  final String seasonName;

  /// "Termina em 20 d 4 h", já formatado por quem conhece a hora local.
  final String remaining;
  final bool hasPass;

  /// Saldo de dracmas do jogador; `null` quando a tela não sabe.
  final int? dracmas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [trailHeaderTop, trailHeaderBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CharacterAvatar(RCharacter.hexi, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TEMPORADA DE ${seasonName.toUpperCase()}',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.black38, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                Text(
                  remaining,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Sem `Flexible`: com um `Expanded` na linha, dar fator flexível aos
          // pills dividiria a barra ao meio e empurraria o saldo para o centro.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                if (dracmas != null)
                  _pill(coin: true, label: formatPoints(dracmas!)),
                if (hasPass) _pill(label: 'Passe ativo', filled: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pílula translúcida do mock: fundo preto sobre a gradiente, texto branco.
  Widget _pill({
    required String label,
    bool coin = false,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: filled ? trailAccent : Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: filled
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coin) ...[const DracmaCoin(size: 16), const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: filled ? trailAccentInk : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
