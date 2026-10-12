import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_image_provider.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/terms_screen.dart';
import '../state/app_state.dart';
import 'game_nav.dart';
import 'glass_panel.dart';

/// O menu do app, no `endDrawer` da casca: abre pelo botão do HUD, do mesmo
/// lado direito em que o botão está. Alterna as abas e dá acesso a mercado,
/// configurações, ajuda, tutorial e saída. As cores vêm do tema (claro/escuro).
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

  void _goTab(BuildContext context, int index) {
    Navigator.of(context).pop();
    onSelectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final profile = state.profile;
    final photo = profileImageProvider(profile?.photoUrl);
    return Drawer(
      // Fundo transparente: o vidro é o `GlassPanel` abaixo, que desfoca a
      // tela principal atrás do menu (o véu leve vem do `drawerTheme`).
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassPanel(
        // O menu entra pela direita: o canto arredondado é o que fica solto, à
        // esquerda.
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(16),
        ),
        child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Semantics(
              header: true,
              label: 'Conta de ${profile?.fullName ?? 'RUNOVER!'}',
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 96),
                    child: Row(
                      children: [
                        // Perfil clicável: abre a aba Perfil.
                        Expanded(
                          flex: 6,
                          child: Material(
                            color: colors.primary,
                            child: InkWell(
                              onTap: () => _goTab(context, 4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.onPrimary,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: colors.onPrimary,
                                        foregroundImage: photo,
                                        onForegroundImageError: photo != null
                                            ? (_, _) {}
                                            : null,
                                        child: Text(
                                          (profile?.username.isEmpty ?? true)
                                              ? '?'
                                              : profile!.username[0]
                                                    .toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            profile?.fullName ?? 'RUNOVER!',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: colors.onPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (profile != null)
                                            Text(
                                              '@${profile.username}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.onPrimary
                                                    .withValues(alpha: 0.8),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Identidade visual do app.
                        Expanded(
                          flex: 4,
                          child: Container(
                            color: colors.secondary,
                            child: Center(
                              child: Image.asset(
                                'assets/images/runner.png',
                                height: 52,
                                color: colors.onSecondary,
                                semanticLabel: 'RUNOVER!',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final (index, tab) in kGameTabs.indexed)
              ListTile(
                key: Key('drawer-tab-${tab.label}'),
                leading: Icon(
                  selectedIndex == index ? tab.activeIcon : tab.icon,
                  color: selectedIndex == index
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                title: Text(
                  tab.label,
                  style: TextStyle(
                    fontWeight: selectedIndex == index
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: selectedIndex == index
                        ? colors.primary
                        : colors.onSurface,
                  ),
                ),
                selected: selectedIndex == index,
                selectedTileColor: colors.primary.withValues(alpha: 0.1),
                onTap: () => _goTab(context, index),
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.storefront_outlined,
                color: colors.onSurfaceVariant,
              ),
              title: const Text('Mercado'),
              subtitle: state.profile == null
                  ? null
                  : Text('${state.profile!.coinsBalance} dracmas'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: colors.onSurfaceVariant,
              ),
              title: const Text('Configurações'),
              onTap: () {
                final current = state.profile;
                if (current == null) return;
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(profile: current),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.help_outline,
                color: colors.onSurfaceVariant,
              ),
              title: const Text('Termos e privacidade'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.school_outlined,
                color: colors.onSurfaceVariant,
              ),
              title: const Text('Ver tutorial'),
              onTap: () {
                final app = context.read<AppState>();
                Navigator.of(context).pop();
                onSelectTab(0);
                app.requestTour();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: colors.error,
              ),
              title: Text('Sair', style: TextStyle(color: colors.error)),
              onTap: () {
                Navigator.of(context).pop();
                state.logout();
              },
            ),
          ],
        ),
      ),
      ),
    );
  }
}
