import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import 'centered_content.dart';
import 'runover_ui.dart';

/// As abas do app, na ordem do `HomeShell`. A barra de baixo e o drawer
/// desenham todas a partir daqui — uma lista só para as duas não poderem
/// divergir.
class GameTab {
  const GameTab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const kGameTabs = <GameTab>[
  GameTab('Mapa', Icons.map_outlined, Icons.map),
  GameTab('Corridas', Icons.directions_run, Icons.directions_run),
  GameTab('Ranking', Icons.emoji_events_outlined, Icons.emoji_events),
  GameTab('Equipe', Icons.groups_outlined, Icons.groups),
  GameTab('Perfil', Icons.person_outline, Icons.person),
];

/// Índice da aba Equipe, o único destino que hoje tem aviso próprio (convite
/// de equipe pendente).
const kTeamTabIndex = 3;

/// Índice da aba Perfil, desenhada com o avatar em vez de um ícone.
const kProfileTabIndex = 4;

/// A partir desta largura a janela tem canto sobrando no pé da tela para a
/// ficha da conta. Mais estreita que isso, o atalho de perfil já é o próprio
/// avatar da barra — a ficha repetiria o destino sem espaço.
///
/// O número é o da janela larga do app (`kWideWindowMinWidth`), o mesmo que
/// divide as telas em bandas: dois degraus diferentes fariam a ficha aparecer
/// numa largura em que a tela ainda é de uma coluna.
const kAccountChipMinWidth = kWideWindowMinWidth;

/// Barra de navegação do app, em qualquer largura: painel curto encostado no pé
/// da tela, com o destino ativo vestido pelo gradiente da marca e o avatar no
/// lugar do ícone de Perfil. O menu com Mercado, Configurações e saída é o
/// drawer, que abre pelo botão do HUD e cai do mesmo lado dele.
class GameNavBar extends StatelessWidget {
  const GameNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    this.alerted = const {},
  });

  final int index;
  final ValueChanged<int> onSelect;

  /// Índices com ponto de aviso. Só aparece quando há motivo real atrás.
  final Set<int> alerted;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: pal.hud,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: pal.border.withValues(alpha: 0.7)),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), offset: Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < kGameTabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _NavItem(
                    tab: kGameTabs[i],
                    active: i == index,
                    alerted: alerted.contains(i),
                    useAvatar: i == kProfileTabIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ficha da conta no canto do pé da tela: avatar e @usuário. O toque abre o
/// perfil, que é onde o cartão de identidade mostra e troca a presença — a
/// presença não aparece aqui de propósito.
class AccountChip extends StatelessWidget {
  const AccountChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final profile = context.watch<AppState>().profile;
    if (profile == null) return const SizedBox.shrink();
    final photo = profileImageProvider(profile.photoUrl);
    return ConstrainedBox(
      // No canto sobra espaço de sobra; a ficha não cresce até a barra inteira.
      constraints: const BoxConstraints(maxWidth: 220),
      child: Semantics(
        button: true,
        label: 'Abrir o meu perfil',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: pal.border.withValues(alpha: 0.7)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Avatar(profile: profile, photo: photo, size: 40),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '@${profile.username}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pal.heading,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// O avatar da conta, do tamanho que o chamador pede. A foto que o servidor
/// guarda vem primeiro; sem foto, a inicial do usuário sobre o gradiente.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.photo, this.size = 40});

  final UserProfile profile;
  final ImageProvider? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = profile.username.isEmpty
        ? '?'
        : profile.username[0].toUpperCase();
    final label = TextStyle(
      color: Pal.onAccent,
      fontWeight: FontWeight.w900,
      fontSize: size * 0.42,
    );
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RGrad.orange,
      ),
      child: ClipOval(
        child: photo == null
            ? Center(child: Text(initial, style: label))
            : Image(
                image: photo!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(initial, style: label),
                ),
              ),
      ),
    );
  }
}

/// Um destino da barra de baixo: ícone (ou avatar) em cima, nome embaixo, o
/// ativo dentro da pílula em gradiente.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.alerted,
    required this.useAvatar,
    required this.onTap,
  });

  final GameTab tab;
  final bool active;
  final bool alerted;
  final bool useAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 42,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Badge(
                      active: active,
                      useAvatar: useAvatar,
                      icon: active ? tab.activeIcon : tab.icon,
                    ),
                    if (alerted)
                      const Positioned(right: -2, top: 2, child: _AlertDot()),
                  ],
                ),
              ),
            ),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // O nome fica fora da pílula, sobre o painel da barra: vem do
                // tema, e por isso se lê nos dois.
                color: active ? pal.heading : pal.muted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.active,
    required this.useAvatar,
    required this.icon,
  });

  final bool active;
  final bool useAvatar;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    if (useAvatar) return const _NavAvatar(size: 34);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: active ? RGrad.header : null,
        borderRadius: BorderRadius.circular(999),
        boxShadow: active
            ? const [
                BoxShadow(color: Color(0x40000000), offset: Offset(0, 3)),
              ]
            : null,
      ),
      // Branco só aqui dentro: o gradiente da marca é fixo nos dois temas, e é
      // o único fundo desta barra que pede tinta clara por cima.
      child: Icon(icon, color: active ? Colors.white : pal.muted, size: 22),
    );
  }
}

/// O avatar do HUD dentro da barra, para o destino Perfil não virar ícone.
class _NavAvatar extends StatelessWidget {
  const _NavAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    if (profile == null) {
      return Icon(Icons.person, size: 22, color: Pal.of(context).muted);
    }
    return _Avatar(
      profile: profile,
      photo: profileImageProvider(profile.photoUrl),
      size: size,
    );
  }
}

/// Ponto de aviso: só existe quando há algo esperando do outro lado.
class _AlertDot extends StatelessWidget {
  const _AlertDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE5484D),
    ),
  );
}
