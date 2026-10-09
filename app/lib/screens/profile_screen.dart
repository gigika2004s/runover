import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/profile_image_provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/cosmetics.dart';
import '../widgets/level_badge.dart';
import 'app_footer.dart';
import 'terms_screen.dart';
import 'edit_profile_screen.dart';
import 'shop_screen.dart';
import 'runs_screen.dart';
import '../widgets/profile_activity.dart';

/// RF05/RF13/RF19 — perfil, estatísticas, progressão e histórico do usuário.
///
/// Cosméticos da loja são opcionais: o perfil e o mural funcionam mesmo
/// quando o catálogo ou as corridas recentes falham (lista vazia).
Future<List<ShopItem>> _catalogOrEmpty(ApiClient api) async {
  try {
    return await api.getShopCatalog();
  } catch (_) {
    return const <ShopItem>[];
  }
}

Future<List<Map<String, dynamic>>> _recentRunsOrEmpty(ApiClient api) async {
  try {
    final runs = await api.listRuns();
    return runs.take(3).toList();
  } catch (_) {
    return const <Map<String, dynamic>>[];
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static String formatPlaytime(int seconds) {
    if (seconds <= 0) return '0min';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '${h}h ${m}min' : '${h}h';
    return '${m}min';
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>>? _progress;
  Future<List<ShopItem>>? _catalog;
  bool _photoBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    if (state.profile != null) {
      _progress ??= state.api.getProgress();
      _catalog ??= _catalogOrEmpty(state.api);
    }
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    final progressRequest = state.api.getProgress();
    final catalogRequest = _catalogOrEmpty(state.api);
    setState(() {
      _progress = progressRequest;
      _catalog = catalogRequest;
    });
    try {
      await Future.wait([
        state.refreshProfile(),
        progressRequest,
        catalogRequest,
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível atualizar todos os dados. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  void _retryProgress() {
    final api = context.read<AppState>().api;
    setState(() {
      _progress = api.getProgress();
      _catalog = _catalogOrEmpty(api);
    });
  }

  Future<void> _openShop() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ShopScreen()));
    if (!mounted) return;
    _refresh();
  }

  Future<void> _savePhoto(String? photoUrl) async {
    if (_photoBusy) return;
    final app = context.read<AppState>();
    final current = app.profile;
    if (current == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _photoBusy = true);
    try {
      await app.api.updateProfile(
        photoUrl: photoUrl ?? '',
        distanceUnits: current.distanceUnits,
        weeklyFrequency: current.weeklyFrequency,
        trainingDays: current.trainingDays,
        activityLevel: current.activityLevel,
      );
      await app.refreshProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            photoUrl == null ? 'Foto removida.' : 'Foto atualizada.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _uploadPhoto() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      final avatar = fitAvatarPhoto(await image.readAsBytes());
      if (avatar == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Escolha uma imagem JPG, PNG ou WebP.'),
            ),
          );
        }
        return;
      }
      await _savePhoto(
        'data:${avatar.mimeType};base64,${base64Encode(avatar.bytes)}',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a foto. Tente outra imagem.'),
          ),
        );
      }
    }
  }

  void _showPhotoOptions() {
    final hasPhoto =
        (context.read<AppState>().profile?.photoUrl?.isNotEmpty ?? false);
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Alterar foto do perfil',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              title: Center(
                child: Text(
                  'Carregar foto',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _uploadPhoto();
              },
            ),
            const Divider(height: 1),
            if (hasPhoto)
              ListTile(
                title: Center(
                  child: Text(
                    'Remover foto atual',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _savePhoto(null);
                },
              ),
            if (hasPhoto) const Divider(height: 1),
            ListTile(
              title: Center(
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final profile = appState.profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final identity = FutureBuilder<List<ShopItem>>(
      future: _catalog,
      builder: (context, snapshot) {
        final catalog = snapshot.data;
        final frame = findItem(catalog ?? const [], profile.equippedFrame);
        final avatarItem = findItem(catalog ?? const [], profile.equippedAvatar);
        final banner = findItem(catalog ?? const [], profile.equippedBanner);
        final nameStyle = findItem(
          catalog ?? const [],
          profile.equippedNameStyle,
        );
        final effect = findItem(catalog ?? const [], profile.equippedEffect);
        final gradient = bannerGradient(banner);
        final displayName = profile.fullName.trim().isEmpty
            ? profile.username
            : profile.fullName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ProfileCard(
                  child: Column(
                    children: [
                      if (gradient != null)
                        Container(
                          height: 72,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      Semantics(
                        button: true,
                        label: 'Alterar foto do perfil',
                        child: GestureDetector(
                          onTap: _photoBusy ? null : _showPhotoOptions,
                          child: FramedAvatar(
                            radius: 40,
                            image: profileAvatarImage(
                              profile.photoUrl,
                              avatarItem,
                            ),
                            fallbackLetter: profile.username.isEmpty
                                ? '?'
                                : profile.username[0],
                            frame: frame,
                            avatarItem: avatarItem,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: styledName(
                          displayName,
                          nameStyle,
                          const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.5,
                          ),
                        ),
                      ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  LevelBadge(level: profile.level),
                  if (profile.teamName != null)
                    Chip(
                      avatar: const Icon(Icons.groups_outlined, size: 17),
                      label: Text(profile.teamName!),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    profile.isPublic ? Icons.public : Icons.lock_outline,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    profile.isPublic ? 'Perfil público' : 'Perfil privado',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Expanded(
                    child: ProfileMetric(
                      value: '${profile.totalScore}',
                      label: 'Pontos',
                    ),
                  ),
                  Expanded(
                    child: ProfileMetric(
                      value: '${profile.territoriesCount}',
                      label: 'Territórios',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(profile: profile),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar perfil'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openShop,
                  icon: const Icon(
                    Icons.storefront_outlined,
                    size: 18,
                  ),
                  label: Text(
                    'Explorar a loja · ${profile.coinsBalance} moedas',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (effect != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ProfileEffectOverlay(effect: effect),
            ),
          ),
      ],
    ),
        const SizedBox(height: 16),
        ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sua evolução',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              LevelProgress(
                level: profile.level,
                progress: profile.levelProgress,
                pointsToNext: profile.pointsToNextLevel,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.leaderboard_outlined,
                    color: RunoverColors.territory,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile.rankPosition == null
                          ? 'Sem posição no ranking'
                          : '${profile.rankPosition}º lugar no ranking',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: RunoverColors.territory,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${ProfileScreen.formatPlaytime(profile.playSeconds)} de tempo de jogo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
          ],
        );
      },
    );
    final activity = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _progress,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ProfileCard(
                child: SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return ProfileCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 32,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar suas atividades.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retryProgress,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileActivity(progress: snapshot.data!),
                const SizedBox(height: 16),
                _MuralCard(
                  progress: snapshot.data!,
                  onChanged: _refresh,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        ProfileCard(
          child: Column(
            children: [
              _profileLink(
                Icons.directions_run,
                'Minhas corridas',
                'Veja seus percursos e atividades',
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const RunsScreen())),
              ),
              const Divider(height: 24),
              _profileLink(
                Icons.emoji_events_outlined,
                'Histórico de conquistas',
                'Acompanhe seus territórios e pontos',
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
          child: const Text(
            'Termos de Uso e Política de Privacidade',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        actions: [
          ThemeModeButton(
            mode: appState.themeMode,
            onSelected: appState.setThemeMode,
          ),
          IconButton(
            tooltip: 'Loja de cosméticos',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Atualizar perfil',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 20),
                        activity,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 320, child: identity),
                      const SizedBox(width: 24),
                      Expanded(child: activity),
                    ],
                  );
                },
                  ),
                  const SizedBox(height: 32),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileLink(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: RunoverColors.route),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Mural do perfil: widgets que o dono escolheu exibir (via API).
/// Personalização em "Personalizar": ordem e visibilidade de cada widget.
class _MuralCard extends StatefulWidget {
  const _MuralCard({required this.progress, required this.onChanged});

  final Map<String, dynamic> progress;
  final VoidCallback onChanged;

  @override
  State<_MuralCard> createState() => _MuralCardState();
}

class _MuralCardState extends State<_MuralCard> {
  late Future<List<ShopItem>> _catalog;
  late Future<List<Map<String, dynamic>>> _runs;

  @override
  void initState() {
    super.initState();
    final api = context.read<AppState>().api;
    _catalog = _catalogOrEmpty(api);
    _runs = _recentRunsOrEmpty(api);
  }

  void _reload() {
    final api = context.read<AppState>().api;
    setState(() {
      _catalog = _catalogOrEmpty(api);
      _runs = _recentRunsOrEmpty(api);
    });
    widget.onChanged();
  }

  Future<void> _customize(UserProfile profile) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MuralCustomizeSheet(profile: profile),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    if (profile == null) return const SizedBox.shrink();
    final widgets = profile.muralWidgets.isEmpty
        ? const ['emoticons', 'conquistas', 'atividades', 'estatisticas']
        : profile.muralWidgets;
    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mural',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _customize(profile),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Personalizar'),
              ),
            ],
          ),
          FutureBuilder<List<ShopItem>>(
            future: _catalog,
            builder: (context, catalogSnap) {
              final catalog = catalogSnap.data ?? const <ShopItem>[];
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _runs,
                builder: (context, runsSnap) {
                  final runs = runsSnap.data ?? const <Map<String, dynamic>>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < widgets.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        _muralSection(
                          context,
                          widgets[i],
                          profile,
                          catalog,
                          runs,
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _muralSection(
    BuildContext context,
    String id,
    UserProfile profile,
    List<ShopItem> catalog,
    List<Map<String, dynamic>> runs,
  ) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    switch (id) {
      case 'emoticons':
        if (profile.equippedEmoticons.isEmpty) {
          return Text(
            'Sem emoticons — explore a loja para decorar seu mural.',
            style: TextStyle(color: muted),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in profile.equippedEmoticons)
              Text(e, style: const TextStyle(fontSize: 30)),
          ],
        );
      case 'conquistas':
        final badges = ((widget.progress['badges'] as List?) ?? const [])
            .whereType<Map>()
            .where((b) => b['earned'] == true)
            .toList();
        if (badges.isEmpty) {
          return Text(
            'Nenhuma conquista ainda — vá correr!',
            style: TextStyle(color: muted),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in badges)
              Chip(
                avatar: const Icon(Icons.verified_outlined, size: 18),
                label: Text('${b['name']}'),
              ),
          ],
        );
      case 'atividades':
        if (runs.isEmpty) {
          return Text(
            'Nenhuma atividade ainda.',
            style: TextStyle(color: muted),
          );
        }
        return Column(
          children: [
            for (final run in runs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.directions_run),
                title: Text('${run['name'] ?? 'Corrida'}'),
                subtitle: Text(_runSubtitle(run)),
                dense: true,
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RunsScreen()),
                ),
                child: const Text('Ver tudo'),
              ),
            ),
          ],
        );
      case 'estatisticas':
        return Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            ProfileMetric(
              value: '${profile.totalScore}',
              label: 'Pontos',
            ),
            ProfileMetric(
              value: '${profile.territoriesCount}',
              label: 'Territórios',
            ),
            ProfileMetric(
              value: 'Nv ${profile.level}',
              label: 'Nível',
            ),
            ProfileMetric(
              value: '${profile.coinsBalance}',
              label: 'Moedas',
            ),
          ],
        );
      case 'cosmeticos':
        final names = [
          profile.equippedAvatar,
          profile.equippedFrame,
          profile.equippedEffect,
          profile.equippedBanner,
          profile.equippedNameStyle,
        ].whereType<String>().map(
          (id) =>
              catalog.where((c) => c.id == id).map((c) => c.name).firstOrNull ??
              id,
        );
        if (names.isEmpty) {
          return Text(
            'Nenhum cosmético — explore a loja.',
            style: TextStyle(color: muted),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final n in names) Chip(label: Text(n))],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

String _runSubtitle(Map<String, dynamic> run) {
  final meters = (run['distance_m'] as num?)?.toDouble();
  final km = meters == null ? '—' : '${(meters / 1000).toStringAsFixed(2).replaceAll('.', ',')} km';
  final at = DateTime.tryParse('${run['started_at']}');
  final date = at == null ? '' : ' · ${at.day}/${at.month}/${at.year}';
  return '$km$date';
}

/// Planilha de personalização do mural: liga/desliga e ordena os widgets.
/// Salva via API (`PATCH /users/me`), validado no servidor.
class _MuralCustomizeSheet extends StatefulWidget {
  const _MuralCustomizeSheet({required this.profile});
  final UserProfile profile;

  @override
  State<_MuralCustomizeSheet> createState() => _MuralCustomizeSheetState();
}

class _MuralCustomizeSheetState extends State<_MuralCustomizeSheet> {
  late List<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.profile.muralWidgets);
  }

  void _move(int index, int delta) {
    final next = index + delta;
    if (next < 0 || next >= _selected.length) return;
    setState(() {
      final id = _selected.removeAt(index);
      _selected.insert(next, id);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final app = context.read<AppState>();
      final current = app.profile;
      if (current == null) return;
      final updated = await app.api.updateProfile(
        distanceUnits: current.distanceUnits,
        weeklyFrequency: current.weeklyFrequency,
        trainingDays: current.trainingDays,
        activityLevel: current.activityLevel,
        muralWidgets: _selected,
      );
      app.applyUpdatedProfile(updated);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Personalizar mural',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha e ordene os widgets do seu perfil.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final entry in muralWidgetMeta.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(entry.value.$2),
                title: Text(entry.value.$1),
                value: _selected.contains(entry.key),
                onChanged: (checked) => setState(() {
                  _selected.remove(entry.key);
                  if (checked == true) _selected.add(entry.key);
                }),
              ),
            if (_selected.isNotEmpty) ...[
              const Divider(),
              const Text('Ordem de exibição:'),
              for (var i = 0; i < _selected.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(muralWidgetMeta[_selected[i]]?.$1 ?? _selected[i]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Subir',
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: i == 0 ? null : () => _move(i, -1),
                      ),
                      IconButton(
                        tooltip: 'Descer',
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: i == _selected.length - 1
                            ? null
                            : () => _move(i, 1),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando…' : 'Salvar mural'),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({
    super.key,
    required this.mode,
    required this.onSelected,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onSelected;

  static const _options = [
    (ThemeMode.system, Icons.brightness_auto_outlined, 'Sistema'),
    (ThemeMode.light, Icons.light_mode_outlined, 'Claro'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Escuro'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = _options.firstWhere((o) => o.$1 == mode);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Tema do app',
      icon: Icon(current.$2),
      initialValue: mode,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final (value, icon, label) in _options)
          PopupMenuItem(
            value: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                if (value == mode) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.check,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.getMyHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico')),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: RunoverColors.route),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma atividade ainda — vá conquistar um território!',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = items[i];
              final positive = e.delta >= 0;
              return ListTile(
                leading: Icon(
                  positive ? Icons.emoji_events : Icons.trending_down,
                  color: positive ? RunoverColors.territory : Colors.redAccent,
                ),
                title: Text(e.territoryName ?? 'Território removido'),
                subtitle: Text(
                  '${e.reason} · ${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
                ),
                trailing: Text(
                  '${positive ? '+' : ''}${e.delta} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: positive
                        ? RunoverColors.territory
                        : Colors.redAccent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
