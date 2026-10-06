import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_image_provider.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/terms_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [Color(0xFF2A1408), Color(0xFF082A30)]
                        : const [
                            RunoverColors.route,
                            RunoverColors.territory,
                          ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -12,
                      top: -16,
                      child: Image.asset(
                        'assets/images/runner.png',
                        height: 104,
                        color: Colors.white.withValues(alpha: 0.16),
                        semanticLabel: null,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            foregroundImage: photo,
                            onForegroundImageError: photo != null
                                ? (_, _) {}
                                : null,
                            child: Text(
                              (profile?.username.isEmpty ?? true)
                                  ? '?'
                                  : profile!.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: RunoverColors.route,
                              ),
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
                                  color: Colors.white,
                                ),
                              ),
                              if (profile != null)
                                Text(
                                  '@${profile.username}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
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
