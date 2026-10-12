import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/insignia.dart';
import 'package:runover_app/widgets/league_emblem.dart';
import 'package:runover_app/widgets/level_badge.dart';
import 'package:runover_app/widgets/runover_ui.dart';

/// A regra do varredura de temas.
///
/// Toda cor que vem de fora do tema — a liga do servidor, a categoria de uma
/// insígnia, a raridade da loja — foi desenhada sobre o cartão escuro do mock.
/// Soltas no tema claro elas somem; por isso o kit tem três portas de tinta:
/// [legibleInk] (acento sobre superfície), [Pal.successInk]/[Pal.goldInk] (as
/// tintas de estado) e [inkOnAccent] (tinta sobre enchimento de acento).
///
/// Este arquivo trava o contrato das três e ainda varre os widgets que as usam
/// em cada superfície do tema, atrás de qualquer tinta que não se lê.
/// As chaves de categoria que o servidor devolve em `GET /badges`: cada uma
/// traz a cor que virou tinta no app.
const categoryKeys = [
  'corridas',
  'territorios',
  'distancia',
  'acumulados',
  'equipe',
  'temporada',
  'outras',
];

void main() {
  /// Contraste mínimo WCAG: 4,5:1 para texto, 3:1 para ícone (1.4.11).
  const minTextContrast = 4.5;
  const minIconContrast = 3.0;

  /// Os acentos que de fato aparecem na tela: as oito cores da escada, as seis
  /// do mapa rival, as categorias de insígnia, as raridades da loja e o
  /// brand ing do tema.
  const accents = <Color>[
    Color(0xFF8A94A6), // Largada / corridas
    Color(0xFFD9822B), // Trote
    Color(0xFFC9CFD6), // Ritmo
    Color(0xFFFFB020), // Pódio / temporada
    Color(0xFF22D3EE), // Turbo / acumulados
    Color(0xFFA78BFA), // Elite / equipe
    Color(0xFF34D399), // Mestre / distância
    Color(0xFFF472B6), // Lenda
    Color(0xFFE5484D), // Territórios / perda
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFF8E24AA),
    Color(0xFF1E88E5),
    Color(0xFFF9A825),
    Color(0xFF22C55E), // verde de posse da loja
    Color(0xFFDC2626),
    Pal.gold,
    Pal.teal,
    Pal.orange,
    Pal.purple,
    Pal.team,
    RunoverColors.route,
    RunoverColors.routeDark,
    RunoverColors.territory,
    RunoverColors.territoryDark,
  ];

  /// Os enchimentos sólidos que recebem tinta por cima em todo o app.
  final accentFills = <Color>[
    Color(0xFF22C55E),
    Pal.gold,
    Pal.teal,
    Pal.orange,
    Pal.purple,
    Pal.purpleDark,
    Pal.onAccent,
    Pal.team,
    RunoverColors.route,
    RunoverColors.routeDark,
    RunoverColors.territory,
    RunoverColors.territoryDark,
    Color(0xFFE8452C), // base de [RGrad.orange]
    Color(0xFF14907A), // base de [RGrad.teal]
    Color(0xFFD9921A), // base de [RGrad.gold]
    Color(0xFF9C2A8F), // base de [RGrad.hud]
    // As categorias da insígnia viram hexágono cheio quando ganhas.
    for (final key in categoryKeys) badgeCategoryStyle(key).color,
  ];

  /// Lê [read] dentro de um `MaterialApp` montado no brilho pedido.
  Future<T> inTheme<T>(
    WidgetTester tester,
    Brightness brightness,
    T Function(BuildContext context) read,
  ) async {
    late T value;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRunoverTheme(brightness: brightness),
        home: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  for (final brightness in Brightness.values) {
    final name = brightness == Brightness.dark ? 'escuro' : 'claro';

    testWidgets('legibleInk entrega 4,5:1 em toda superfície do tema $name', (
      tester,
    ) async {
      final offenders = await inTheme(tester, brightness, (context) {
        return accents
            .map((accent) => (accent: accent, ink: legibleInk(accent, context)))
            .where(
              (pair) => contrastOnSurfaces(pair.ink, context) < minTextContrast,
            )
            .toList();
      });
      expect(
        offenders,
        isEmpty,
        reason: offenders
            .map((p) => '${_hex(p.accent)} virou ${_hex(p.ink)}')
            .join('\n'),
      );
    });

    testWidgets('as tintas de estado passam de 4,5:1 no tema $name', (
      tester,
    ) async {
      final ratios = await inTheme(
        tester,
        brightness,
        (context) => {
          'sucesso': contrastOnSurfaces(Pal.successInk(context), context),
          'ouro': contrastOnSurfaces(Pal.goldInk(context), context),
          'suave': contrastOnSurfaces(Pal.of(context).muted, context),
          'título': contrastOnSurfaces(Pal.of(context).heading, context),
        },
      );
      ratios.forEach((label, ratio) {
        expect(
          ratio,
          greaterThanOrEqualTo(minTextContrast),
          reason: 'a tinta $label ficou em ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });

    testWidgets('inkOnAccent escolhe a tinta legível sobre o acento $name', (
      tester,
    ) async {
      final offenders = accentFills
          .map((fill) => (fill: fill, ink: inkOnAccent(fill)))
          .where((pair) => contrastRatio(pair.ink, pair.fill) < minTextContrast)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason: offenders
            .map(
              (p) =>
                  '${_hex(p.ink)} sobre ${_hex(p.fill)} ficou em '
                  '${contrastRatio(p.ink, p.fill).toStringAsFixed(2)}:1',
            )
            .join('\n'),
      );
    });

    testWidgets(
      'o emblema ganho tinge o ícone pela cor do próprio hexágono $name',
      (tester) async {
        final problems = <String>[];
        for (final key in categoryKeys) {
          final style = badgeCategoryStyle(key);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildRunoverTheme(brightness: brightness),
              home: Scaffold(
                body: Center(
                  child: BadgeEmblem(
                    icon: style.icon,
                    color: style.color,
                    earned: true,
                  ),
                ),
              ),
            ),
          );
          // O hexágono cheio é pintado por CustomPaint, então o fundo do ícone é a
          // cor da categoria — não a superfície do tema.
          final ink = tester.widget<Icon>(find.byType(Icon)).color;
          final ratio = contrastRatio(ink!, style.color);
          if (ratio < minIconContrast) {
            problems.add(
              '$key: ${_hex(ink)} sobre ${_hex(style.color)} ficou em '
              '${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      },
    );

    testWidgets('os selos do kit se lêem em cada superfície do tema $name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRunoverTheme(brightness: brightness),
          home: Builder(
            builder: (context) {
              final pal = Pal.of(context);
              return DecoratedBox(
                decoration: BoxDecoration(color: pal.panel),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final surface in [
                        pal.card,
                        pal.chip,
                        pal.hud,
                        Theme.of(context).colorScheme.surface,
                      ])
                        for (final accent in [
                          accents[0],
                          accents[4],
                          accents[6],
                          accents[7],
                          accents[17],
                        ])
                          _plate(
                            surface,
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                LevelBadge(level: 7),
                                LeagueBadgeChip(
                                  badge: LeagueBadge(
                                    league: 'turbo',
                                    name: 'Turbo',
                                    color: _hex(accent),
                                    shape: 'hexagon',
                                    division: 2,
                                  ),
                                ),
                                InfoPill('1,2 km', icon: Icons.route),
                              ],
                            ),
                          ),
                      // Emblema bloqueado: o hexágono é contorno e a cor da
                      // categoria é tinta sobre a superfície. A versão ganha
                      // pinta o fundo com a própria cor, fora da árvore, e tem
                      // teste próprio.
                      for (final surface in [
                        pal.card,
                        pal.chip,
                        pal.hud,
                        Theme.of(context).colorScheme.surface,
                      ])
                        for (final key in categoryKeys)
                          _plate(
                            surface,
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                BadgeEmblem(
                                  icon: badgeCategoryStyle(key).icon,
                                  color: badgeCategoryStyle(key).color,
                                  size: 46,
                                ),
                              ],
                            ),
                          ),
                      // Sobre gradiente fixo a tinta clara do mock continua
                      // certa — a varredura ignora esses fundos.
                      for (final gradient in const [
                        RGrad.orange,
                        RGrad.gold,
                        RGrad.teal,
                        RGrad.hud,
                      ])
                        _plateWith(
                          BoxDecoration(gradient: gradient),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              InfoPill(
                                '4,8 km',
                                icon: Icons.route,
                                onColored: true,
                              ),
                              // Tinta branca sobre a faixa de gradiente: a
                              // auditoria tem de deixar passar, porque o fundo
                              // é fixo nos dois temas.
                              const Text(
                                'Sua evolução',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      // Os cartões aqui não animam; `pump` basta e é a regra para telas com
      // loops.
      await tester.pump();
      expectLegibleInk(
        tester,
        minText: minTextContrast,
        minIcon: minIconContrast,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

/// Um fundo liso segurando o widget auditado.
Widget _plate(Color background, Widget child) =>
    _plateWith(BoxDecoration(color: background), child);

Widget _plateWith(Decoration decoration, Widget child) => DecoratedBox(
  decoration: decoration,
  child: Padding(
    padding: const EdgeInsets.all(8),
    // Largura fixa: dentro do scroll vertical a linha ficaria sem limite e o
    // `SectionHeader`, que usa Expanded, reclama.
    child: SizedBox(width: 420, child: child),
  ),
);

/// `#RRGGBB` para montar a cor que o servidor mandaria.
String _hex(Color color) {
  final argb = color.toARGB32();
  return '#${((argb & 0xFFFFFF) | 0x1000000).toRadixString(16).substring(1).toUpperCase()}';
}

/// Varre a árvore atrás de tinta que não se lê sobre o fundo onde pousa.
///
/// O fundo é a primeira placa opaca acima da folha. Se antes dela aparecer um
/// [Decoration] com gradiente, o texto está numa faixa de cor fixa (cartão de
/// modo, banner, trilha do passe) e a tinta clara do mock continua correta nos
/// dois temas — esses ramos ficam de fora da auditoria. Quem pinta o próprio
/// fundo fora da árvore, como o hexágono cheio do emblema ganho, também não
/// cabe aqui; esse contrato é o teste de [inkOnAccent] sobre [accentFills].
void expectLegibleInk(
  WidgetTester tester, {
  double minText = 4.5,
  double minIcon = 3.0,
}) {
  final problems = <String>[];

  void audit(Element leaf, Color? ink, String label, double minimum) {
    if (ink == null) return;
    final backdrop = _backdropFor(leaf);
    if (backdrop.painted) return;
    final background = backdrop.color;
    if (background == null) return;
    final ratio = contrastRatio(ink, background);
    if (ratio < minimum) {
      problems.add(
        '$label: tinta ${_hex(ink)} sobre ${_hex(background)} ficou em '
        '${ratio.toStringAsFixed(2)}:1 (mínimo ${minimum.toStringAsFixed(1)})',
      );
    }
  }

  for (final element in tester.elementList(find.byType(Text))) {
    final text = element.widget as Text;
    final style = DefaultTextStyle.of(element).style.merge(text.style);
    audit(element, style.color, 'Texto "${text.data}"', minText);
  }
  for (final element in tester.elementList(find.byType(Icon))) {
    final icon = element.widget as Icon;
    final color = icon.color ?? IconTheme.of(element).color;
    audit(element, color, 'Ícone ${icon.icon?.codePoint}', minIcon);
  }

  expect(problems, isEmpty, reason: problems.join('\n'));
}

({Color? color, bool painted}) _backdropFor(Element leaf) {
  Color? color;
  var painted = false;
  leaf.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is! BoxDecoration) return true;
      if (decoration.gradient != null) {
        painted = true;
        color = null;
        return false;
      }
      final fill = decoration.color;
      if (fill != null && fill.a > 0.9) {
        color = fill;
        return false;
      }
      return true;
    }
    if (widget is ColoredBox && widget.color.a > 0.9) {
      color = widget.color;
      return false;
    }
    if (widget is Material) {
      final fill = widget.color;
      if (fill != null && fill.a > 0.9) {
        color = fill;
        return false;
      }
    }
    return true;
  });
  return (color: color, painted: painted);
}
