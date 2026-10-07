import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/onboarding.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/cookie_consent.dart';
import '../widgets/guided_tour.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'ranking_screen.dart';
import 'teams_screen.dart';
import 'runs_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _menuKey = GlobalKey();
  final _startKey = GlobalKey();
  final _tabsKey = GlobalKey();

  bool _touring = false;
  bool _tourChecked = false;
  int _seenTourRequests = 0;

  late final _screens = [
    HomeScreen(
      onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
      menuKey: _menuKey,
      startKey: _startKey,
    ),
    const RunsScreen(),
    const RankingScreen(),
    const TeamsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeShowCookieBanner(context),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App voltou ao primeiro plano: renova o "online" da equipe.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().pingPresence();
    }
  }

  List<TourStep> get _steps => [
    TourStep(
      targetKey: _menuKey,
      title: 'Menu lateral',
      text: 'Toque aqui para abrir perfil, abas, tutorial e saída.',
    ),
    TourStep(
      targetKey: _startKey,
      title: 'Iniciar corrida',
      text: 'Toque para começar a registrar um trajeto e conquistar territórios.',
    ),
    TourStep(
      targetKey: _tabsKey,
      title: 'Navegação',
      text: 'Alterne entre Mapa, Corridas, Ranking, Equipe e Perfil.',
    ),
  ];

  Future<void> _finishTour() async {
    try {
      await OnboardingStore.markSeen();
    } catch (_) {
      // Segue mesmo assim; o tour pode reaparecer.
    }
    if (mounted) setState(() => _touring = false);
  }

  void _maybeStartTour() {
    if (_touring || !mounted) return;
    setState(() {
      _index = 0;
      _touring = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<AppState>().tourRequests;
    if (requests != _seenTourRequests) {
      _seenTourRequests = requests;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    } else if (!_tourChecked) {
      _tourChecked = true;
      OnboardingStore.seen().then((seen) {
        if (!seen && mounted) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _maybeStartTour(),
          );
        }
      }).catchError((_) {});
    }
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        selectedIndex: _index,
        onSelectTab: (i) => setState(() => _index = i),
      ),
      body: Stack(
        children: [
          _screens[_index],
          if (_touring)
            GuidedTour(steps: _steps, onFinish: _finishTour),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: _tabsKey,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: RunoverColors.route.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run),
            label: 'Corridas',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Equipe',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
