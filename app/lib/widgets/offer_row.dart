import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../services/profile_image_provider.dart';
import 'cosmetics.dart';

/// Fileira de oferta: arte em caixa de raridade,
/// nome + selos no meio e botão verde de preço à direita.
///
/// Usada pela loja pessoal e pela loja da equipe (que passa seu ícone
/// de preço e a trava de permissão).
class OfferRow extends StatelessWidget {
  const OfferRow({
    super.key,
    required this.item,
    this.subtitle,
    required this.owned,
    required this.equipped,
    required this.busy,
    this.locked = false,
    required this.priceIcon,
    required this.onOpen,
    required this.onBuy,
    required this.onEquip,
  });

  final ShopItem item;
  final String? subtitle;
  final bool owned;
  final bool equipped;
  final bool busy;
  final bool locked;
  final IconData priceIcon;
  final VoidCallback onOpen;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tier = tierFor(item);
    final isBundle = item.category == 'bundle';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              OfferArt(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tier.label} · ${_categoryLabel(item)}'
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: tier.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (equipped)
                          const _OfferPill(
                            label: 'Equipada',
                            color: Color(0xFF22C55E),
                          )
                        else if (owned && isBundle)
                          const _OfferPill(
                            label: 'Na coleção',
                            color: Color(0xFF22C55E),
                          ),
                        if (item.payload['collection'] == 'parceria')
                          const _OfferPill(
                            label: 'Parceria',
                            color: Color(0xFF8B7CFF),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _OfferPriceButton(
                item: item,
                owned: owned,
                equipped: equipped,
                isBundle: isBundle,
                busy: busy,
                locked: locked,
                priceIcon: priceIcon,
                onBuy: onBuy,
                onEquip: onEquip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(ShopItem item) {
  return switch (item.category) {
    'avatar' => 'Avatar',
    'frame' => 'Moldura',
    'effect' => 'Efeito',
    'banner' => 'Faixa',
    'name_style' => 'Nome',
    'emoticon' => 'Emoticon',
    'bundle' => 'Pacote',
    _ => item.category,
  };
}

/// Raridade pela faixa de preço, com as cores da caixa de arte.
class OfferTier {
  const OfferTier(this.label, this.accent, this.background);

  final String label;
  final Color accent;
  final List<Color> background;
}

OfferTier tierFor(ShopItem item) {
  final price = item.price;
  if (price < 200) {
    return const OfferTier(
      'Comum',
      Color(0xFF94A3B8),
      [Color(0xFF64748B), Color(0xFF334155)],
    );
  }
  if (price < 600) {
    return const OfferTier(
      'Raro',
      Color(0xFFF97316),
      [Color(0xFFF97316), Color(0xFF9A3412)],
    );
  }
  if (price < 1200) {
    return const OfferTier(
      'Épico',
      Color(0xFFA855F7),
      [Color(0xFFA855F7), Color(0xFF581C87)],
    );
  }
  return const OfferTier(
    'Lendário',
    Color(0xFFFFC93C),
    [Color(0xFFFFC93C), Color(0xFFB45309)],
  );
}

/// Arte da oferta: caixa 84px na cor da raridade com a prévia animada.
class OfferArt extends StatelessWidget {
  const OfferArt({super.key, required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(item);
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tier.background,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Center(child: ShopPreview(item: item, scale: 0.62)),
          if (item.category == 'effect')
            Positioned.fill(
              child: ProfileEffectOverlay(effect: item),
            ),
        ],
      ),
    );
  }
}

/// Prévia do produto (tamanhos escaláveis para fileira e detalhes).
class ShopPreview extends StatelessWidget {
  const ShopPreview({super.key, required this.item, this.scale = 1.0});

  final ShopItem item;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return switch (item.category) {
      'avatar' => Builder(
        builder: (context) {
          final asset = galleryAvatarAsset(item);
          final style = generatedAvatarStyle(item);
          return FramedAvatar(
            radius: 34 * scale,
            image: asset == null
                ? (style == null
                      ? null
                      : NetworkImage(
                          diceBearAvatarUrl(item.id, style: style),
                        ))
                : AssetImage(asset),
            fallbackLetter: item.name.isEmpty ? '?' : item.name[0],
            avatarItem: item,
          );
        },
      ),
      'frame' => FramedAvatar(
        radius: 34 * scale,
        fallbackLetter: 'V',
        frame: item,
      ),
      'banner' => Breathe(
        seed: item.id,
        child: Container(
          width: 120 * scale,
          height: 72 * scale,
          decoration: BoxDecoration(
            gradient: bannerGradient(item),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
      'name_style' => Breathe(
        seed: item.id,
        child: Text(
          'Nome',
          style: styledName(
            'Nome',
            item,
            TextStyle(fontSize: 26 * scale, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      'effect' => Text(
        (item.payload['kind'] ?? 'sparkle') == 'fire' ? '🔥' : '✨',
        style: TextStyle(fontSize: 44 * scale),
      ),
      'emoticon' => Breathe(
        seed: item.id,
        child: Text(
          ((item.payload['emoji'] as List?) ?? const ['🎽'])
              .take(3)
              .join(' '),
          style: TextStyle(fontSize: 34 * scale),
        ),
      ),
      'bundle' => Breathe(
        seed: item.id,
        child: Text(
          '📦',
          style: TextStyle(fontSize: 44 * scale),
        ),
      ),
      _ => const Icon(Icons.style_outlined, size: 40),
    };
  }
}

/// Botão verde de preço estilo CR (vira Equipar/Equipada quando é seu).
class _OfferPriceButton extends StatelessWidget {
  const _OfferPriceButton({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.isBundle,
    required this.busy,
    required this.locked,
    required this.priceIcon,
    required this.onBuy,
    required this.onEquip,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool isBundle;
  final bool busy;
  final bool locked;
  final IconData priceIcon;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    const darkGreen = Color(0xFF15803D);
    if (!owned) {
      return FilledButton(
        onPressed: busy ? null : onBuy,
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: darkGreen, width: 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_outline, size: 14),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(priceIcon, size: 16),
              ),
            Text(
              item.price == 0 ? 'Resgatar' : formatPoints(item.price),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }
    if (isBundle) {
      return const _OfferOwnedChip(label: 'Na coleção');
    }
    if (equipped) {
      return FilledButton.tonal(
        onPressed: busy ? null : onEquip,
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 16),
            SizedBox(width: 4),
            Text('Equipada'),
          ],
        ),
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : onEquip,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      child: const Text('Equipar'),
    );
  }
}

class _OfferPill extends StatelessWidget {
  const _OfferPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _OfferOwnedChip extends StatelessWidget {
  const _OfferOwnedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Color(0xFF16A34A),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16A34A),
            ),
          ),
        ],
      ),
    );
  }
}
