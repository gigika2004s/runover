import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_image_provider.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/shop_screen.dart';
import '../screens/terms_screen.dart';
import '../state/app_state.dart';

/// Menu lateral do app: alterna as abas e dá acesso a configurações,
/// ajuda, tutorial e saída. As cores vêm do tema (claro/escuro).
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

  static const _tabs = [
    (0, Icons.map_outlined, Icons.map, 'Mapa'),
    (1, Icons.directions_run, Icons.directions_run, 'Corridas'),
    (2, Icons.emoji_events_outlined, Icons.emoji_events, 'Ranking'),
    (3, Icons.groups_outlined, Icons.groups, 'Equipe'),
    (4, Icons.person_outline, Icons.person, 'Perfil'),
  ];

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
            for (final (index, icon, activeIcon, label) in _tabs)
              ListTile(
                key: Key('drawer-tab-$label'),
                leading: Icon(
                  selectedIndex == index ? activeIcon : icon,
                  color: selectedIndex == index
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                title: Text(
                  label,
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
                  : Text('${state.profile!.coinsBalance} moedas'),
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
    );
  }
}
