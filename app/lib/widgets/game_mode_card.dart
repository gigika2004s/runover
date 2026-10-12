/// Cartão de modo de jogo, a peça que se repete entre telas.
///
/// A home usa a grade inteira ([GameModeGrid]) como "ESCOLHA SEU MODO"; o
/// estado vazio de Corridas reaproveita os mesmos cartões para convidar a
/// primeira corrida. Um só lugar desenha o modo — gradiente, personagem,
/// pílulas, etiqueta e botão — para as duas telas não divergirem.
///
/// Nada aqui decide regra de jogo: [GameMode.onPlay] vem da tela, e `null`
/// deixa o botão apagado (o modo aparece sem fingir que dá para jogar).
library;

import 'package:flutter/material.dart';

import 'runover_ui.dart';

/// Largura a partir da qual os cartões de modo vão lado a lado.
const double kModeGridWideWidth = 700;

/// Dados de um modo de jogo para o cartão.
class GameMode {
  const GameMode({
    required this.title,
    required this.description,
    required this.character,
    required this.gradient,
    required this.action,
    required this.pills,
    required this.onPlay,
    this.tag,
    this.ghost = false,
    this.actionKey,
  });

  final String title;
  final String description;
  final RCharacter character;
  final LinearGradient gradient;
  final String action;
  final List<String> pills;
  final String? tag;

  /// Botão com contorno em vez de enchimento: acionável, sem parecer o CTA
  /// de um modo pronto.
  final bool ghost;
  final Key? actionKey;

  /// `null` deixa o botão apagado: o modo aparece na tela sem fingir que dá
  /// para jogar.
  final VoidCallback? onPlay;
}

/// Gradiente de um modo ainda sem regra: a cor se mistura ao roxo fixo do
/// tabuleiro, não ao painel da tela. O cartão continua sendo um cartão de
/// gradiente — texto branco, sombra, tudo — nos dois temas; esmaecer para o
/// painel claro daria creme pálido com título branco, ilegível.
LinearGradient dimmedModeGradient(
  LinearGradient gradient, {
  double amount = 0.45,
}) => LinearGradient(
  begin: gradient.begin,
  end: gradient.end,
  colors: [
    Color.lerp(gradient.colors.first, Pal.purpleDark, amount)!,
    Color.lerp(gradient.colors.last, Pal.purpleDark, amount)!,
  ],
);

/// Grade dos modos: lado a lado na janela larga, empilhados na estreita.
class GameModeGrid extends StatelessWidget {
  const GameModeGrid({super.key, required this.modes, this.stretch = false});

  final List<GameMode> modes;

  /// Quando o pai já dá a altura (janela larga e alta), os cards esticam direto
  /// no `Row`; sem isso é preciso medir o card mais alto com [IntrinsicHeight].
  final bool stretch;

  static const _gap = 18.0;

  List<Widget> _children({required bool fillHeight}) => [
    for (var i = 0; i < modes.length; i++) ...[
      Expanded(
        child: GameModeCard(mode: modes[i], fillHeight: fillHeight),
      ),
      if (i < modes.length - 1) const SizedBox(width: _gap),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    if (stretch) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _children(fillHeight: true),
      );
    }
    return LayoutBuilder(
      builder: (_, c) {
        if (c.maxWidth >= kModeGridWideWidth) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _children(fillHeight: true),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < modes.length; i++) ...[
              if (i > 0) const SizedBox(height: 26),
              GameModeCard(mode: modes[i], fillHeight: false),
            ],
          ],
        );
      },
    );
  }
}

class GameModeCard extends StatelessWidget {
  const GameModeCard({
    super.key,
    required this.mode,
    this.fillHeight = false,
  });

  final GameMode mode;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        GameCard(
          gradient: mode.gradient,
          radius: 20,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                // O brilho atrás do personagem é sombra, não animação: a home
                // é testada com `pumpAndSettle` e um glow pulsante nunca assenta.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.28),
                        blurRadius: 22,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CharacterAvatar(
                    mode.character,
                    size: fillHeight ? 116 : 104,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mode.title.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  height: 1.15,
                  color: Colors.white,
                  shadows: kTextShadow,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mode.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final pill in mode.pills)
                      InfoPill(pill, onColored: true),
                  ],
                ),
              ),
              if (fillHeight) const Spacer() else const SizedBox(height: 16),
              if (fillHeight) const SizedBox(height: 16),
              GameButton(
                key: mode.actionKey,
                label: mode.action,
                expand: true,
                big: true,
                ghost: mode.ghost,
                background: Colors.white,
                // Sem enchimento — fantasma ou apagado — o botão fica sendo a
                // gradiente fixa do cartão, e a tinta ali é branca nos dois
                // temas. O brilho do tema (preto no claro) sobre o dourado
                // escuro do modo "em breve" não se lê.
                foreground: mode.ghost || mode.onPlay == null
                    ? Colors.white
                    : null,
                onPressed: mode.onPlay,
              ),
            ],
          ),
        ),
        if (mode.tag != null)
          Positioned(
            top: -13,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
                  ],
                ),
                child: Text(
                  mode.tag!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: Pal.onAccent,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
