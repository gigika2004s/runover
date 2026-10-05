import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'app_footer.dart';
import 'map_screen.dart';
import 'notifications_screen.dart';
import 'tracking_screen.dart';

/// Tela inicial leve: o mapa só é carregado quando o usuário pede.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      context.read<AppState>().retryPendingRuns().catchError(
        (Object _) => false,
      ),
    );
  }

  void _startRun() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TrackingScreen()));
  }

  void _openMap() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MapScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = context.watch<AppState>().profile;
    final photoUrl = profile?.photoUrl;
    final hasPhoto = photoUrl?.isNotEmpty == true;
    final username = profile?.username ?? '';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Row(
              children: [
                Semantics(
                  button: widget.onOpenProfile != null,
                  label: 'Abrir perfil',
                  child: GestureDetector(
                    onTap: widget.onOpenProfile,
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: RunoverColors.route.withValues(
                        alpha: .12,
                      ),
                      foregroundImage: hasPhoto
                          ? profileImageProvider(photoUrl)
                          : null,
                      onForegroundImageError: hasPhoto ? (_, _) {} : null,
                      child: Text(
                        username.isEmpty ? '?' : username[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Notificações',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'RUNOVER!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/runner.png',
                height: 44,
                color: colors.onSurface,
                semanticLabel: 'Ícone RUNOVER!',
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Domine territórios correndo.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _startRun,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 22,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Iniciar corrida'),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Ver mapa de territórios'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
