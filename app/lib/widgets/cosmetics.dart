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

/// Moldura ao redor do avatar. Itens `animated` ganham brilho pulsante.
class FramedAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = frame == null ? const <Color>[] : _colors(frame!);
    final borderColor = colors.isEmpty
        ? Colors.transparent
        : colors.length == 1
            ? colors.first
            : null;
    final animated =
        (frame?.payload['animated'] == true) ||
        (avatarItem?.payload['animated'] == true);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .12),
      foregroundImage: image,
      onForegroundImageError: image != null ? (_, _) {} : null,
      child: Text(
        fallbackLetter.toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.75,
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
    if (!animated) return ring;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (_, glow, _) => Container(
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
        child: ring,
      ),
      onEnd: () {},
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

/// Provedor de imagem do perfil respeitando o avatar da galeria.
ImageProvider? profileAvatarImage(String? photoUrl, ShopItem? avatarItem) {
  final asset = galleryAvatarAsset(avatarItem);
  if (asset != null) return AssetImage(asset);
  return profileImageProvider(photoUrl);
}

/// Widgets disponíveis para o mural do perfil (ordem = exibição).
const muralWidgetMeta = {
  'emoticons': ('Emoticons', Icons.emoji_emotions_outlined),
  'conquistas': ('Conquistas', Icons.verified_outlined),
  'atividades': ('Atividades', Icons.directions_run),
  'estatisticas': ('Estatísticas', Icons.leaderboard_outlined),
  'cosmeticos': ('Cosméticos', Icons.style_outlined),
};
