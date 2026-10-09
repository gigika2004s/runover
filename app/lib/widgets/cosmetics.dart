import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/profile_image_provider.dart';

/// Renderização dos cosméticos do mercado (molduras, faixas, estilos de
/// nome, efeitos e avatares animados da galeria pronta). Tudo é desenhado
/// em Flutter a partir do `payload` do catálogo (via API) — sem binários.

Color _hex(String hex) {
  final clean = hex.replaceAll('#', '');
  final value = int.parse(
    clean.length == 6 ? 'FF$clean' : clean,
    radix: 16,
  );
  return Color(value);
}

List<Color> _colors(ShopItem item) {
  final raw = item.payload['colors'] as List? ?? const [];
  if (raw.isEmpty) return const [Color(0xFFFFC93C)];
  return [for (final c in raw) _hex('$c')];
}

ShopItem? findItem(List<ShopItem> catalog, String? id) {
  if (id == null) return null;
  for (final item in catalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// Moldura ao redor do avatar. Itens `animated` ganham brilho pulsante
/// em loop (todo o catálogo é animado).
class FramedAvatar extends StatefulWidget {
  const FramedAvatar({
    super.key,
    required this.radius,
    this.image,
    this.fallbackLetter = '?',
    this.frame,
    this.avatarItem,
  });

  final double radius;
  final ImageProvider? image;
  final String fallbackLetter;
  final ShopItem? frame;
  final ShopItem? avatarItem;

  @override
  State<FramedAvatar> createState() => _FramedAvatarState();
}

class _FramedAvatarState extends State<FramedAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _animated =>
      (widget.frame?.payload['animated'] == true) ||
      (widget.avatarItem?.payload['animated'] == true);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (_animated) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(FramedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = (oldWidget.frame?.payload['animated'] == true) ||
        (oldWidget.avatarItem?.payload['animated'] == true);
    if (_animated && !was) {
      _controller.repeat(reverse: true);
    } else if (!_animated && was) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.frame == null
        ? const <Color>[]
        : _colors(widget.frame!);
    final borderColor = colors.isEmpty
        ? Colors.transparent
        : colors.length == 1
            ? colors.first
            : null;
    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .12),
      foregroundImage: widget.image,
      onForegroundImageError: widget.image != null ? (_, _) {} : null,
      child: Text(
        widget.fallbackLetter.toUpperCase(),
        style: TextStyle(
          fontSize: widget.radius * 0.75,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (colors.isEmpty) return avatar;
    final ring = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 3)
            : null,
        gradient: borderColor == null
            ? SweepGradient(colors: [...colors, colors.first])
            : null,
      ),
      child: avatar,
    );
    if (!_animated) return ring;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final glow = 0.6 + 0.4 * _controller.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: .5 * glow),
                blurRadius: 18 * glow,
                spreadRadius: 2 * glow,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ring,
    );
  }
}

/// Respiração sutil em loop para prévias sem animação própria
/// (faixas, nomes, emoticons, pacotes): escala 1 ↔ 1.03 com fase por item.
class Breathe extends StatefulWidget {
  const Breathe({super.key, required this.seed, required this.child});

  final String seed;
  final Widget child;

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _phase;

  @override
  void initState() {
    super.initState();
    var hash = 0;
    for (final unit in widget.seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    _phase = (hash % 1000) / 1000 * 6.283185307;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final s =
            1.0 +
            0.03 *
                math.sin(_controller.value * 6.283185307 + _phase);
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}

/// Faixa do perfil (banner). Devolve `null` quando não há item.
LinearGradient? bannerGradient(ShopItem? banner) {
  if (banner == null) return null;
  final colors = _colors(banner);
  return LinearGradient(
    colors: colors.length == 1 ? [colors.first, colors.first] : colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Nome exibido com o estilo equipado (cor + brilho; arco-íris usa a
/// primeira cor como base e sombra colorida).
TextStyle styledName(String name, ShopItem? style, TextStyle base) {
  if (style == null) return base;
  final colors = _colors(style);
  final glow = style.payload['glow'] == true;
  return base.copyWith(
    color: colors.first,
    shadows: glow
        ? [
            Shadow(
              color: colors.first.withValues(alpha: .7),
              blurRadius: 12,
            ),
          ]
        : null,
  );
}

/// Efeito do perfil: camada animada de brilho/partículas sobre o cartão.
class ProfileEffectOverlay extends StatefulWidget {
  const ProfileEffectOverlay({super.key, required this.effect});
  final ShopItem effect;

  @override
  State<ProfileEffectOverlay> createState() => _ProfileEffectOverlayState();
}

class _ProfileEffectOverlayState extends State<ProfileEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.effect.payload['kind'] ?? 'sparkle';
    final glyph = kind == 'fire' ? '🔥' : '✨';
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          painter: _ParticlesPainter(
            progress: _controller.value,
            glyph: glyph,
          ),
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  _ParticlesPainter({required this.progress, required this.glyph});
  final double progress;
  final String glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    for (var i = 0; i < 8; i++) {
      final x = rng.nextDouble() * size.width;
      final cycle = (progress + i / 8) % 1;
      final y = (size.height + 10) + (-30.0 - size.height - 10) * cycle;
      final opacity = (1 - cycle) * 0.8;
      final painter = TextPainter(
        text: TextSpan(
          text: glyph,
          style: TextStyle(
            fontSize: 14 + rng.nextDouble() * 8,
            color: Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.progress != progress;
}

/// Avatar da galeria pronta: resolve o asset pelo `payload['asset']`.
/// A galeria vive em `assets/avatars/`; itens animados usam o mesmo
/// asset com anel animado (FramedAvatar).
String? galleryAvatarAsset(ShopItem? item) {
  final asset = item?.payload['asset'];
  if (asset is! String || asset.isEmpty) return null;
  return 'assets/avatars/avatar_$asset.png';
}

/// Estilo DiceBear do item gerado (`payload['generated']`), ou null.
String? generatedAvatarStyle(ShopItem? item) {
  final style = item?.payload['generated'];
  if (style is! String || !diceBearAvatarStyles.contains(style)) {
    return null;
  }
  return style;
}

/// Provedor de imagem do perfil: avatar da loja (galeria pronta ou gerado
/// com seed = apelido do dono) e, por último, a foto enviada.
ImageProvider? profileAvatarImage(
  String? photoUrl,
  ShopItem? avatarItem, {
  String? seed,
}) {
  final asset = galleryAvatarAsset(avatarItem);
  if (asset != null) return AssetImage(asset);
  final style = generatedAvatarStyle(avatarItem);
  if (style != null) {
    return NetworkImage(diceBearAvatarUrl(seed ?? '', style: style));
  }
  return profileImageProvider(photoUrl);
}
