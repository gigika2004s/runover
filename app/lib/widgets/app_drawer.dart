import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_image_provider.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/terms_screen.dart';
import '../state/app_state.dart';
import '../screens/onboarding_screen.dart';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    foregroundImage: photo,
                    onForegroundImageError: photo != null ? (_, _) {} : null,
                    child: Text(
                      (profile?.username.isEmpty ?? true)
                          ? '?'
                          : profile!.username[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? 'RUNOVER!',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (profile != null)
                          Text(
                            '@${profile.username}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
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
              title: const Text('Ajuda e feedback'),
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
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (routeContext) => OnboardingScreen(
                      onDone: () => Navigator.of(routeContext).pop(),
                    ),
                  ),
                );
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
