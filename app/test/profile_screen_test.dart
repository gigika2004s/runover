import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/profile_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/profile_activity.dart';

const profileData = {
  'id': 'profile-test',
  'full_name': 'Marina Oliveira',
  'username': 'marina',
  'email': 'marina@example.test',
  'photo_url': null,
  'total_score': 320,
  'territories_count': 4,
  'rank_position': 3,
  'team_name': 'Passo a passo',
  'level': 2,
  'level_progress': .4,
  'points_to_next_level': 100,
  'is_public': true,
  'play_seconds': 5400,
};
const progressData = {
  'runs_count': 12,
  'distance_km': 64.2,
  'longest_run_km': 10.4,
  'goals': [
    {
      'name': 'Correr 10 km nesta semana',
      'value': 7.5,
      'target': 10,
      'unit': 'km',
    },
    {
      'name': 'Correr em 3 dias nesta semana',
      'value': 2,
      'target': 3,
      'unit': 'dias',
    },
  ],
  'badges': [
    {'name': 'Primeira corrida', 'earned': true},
    {'name': 'Primeira conquista', 'earned': false},
  ],
};

void main() {
  Future<void> open(
    WidgetTester tester,
    Size size, {
    bool failFirst = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          requests++;
          if (failFirst && requests == 1) {
            return http.Response('{"detail":"Indisponível"}', 503);
          }
          return http.Response(jsonEncode(progressData), 200);
        }
        if (request.url.path == '/users/me') {
          return http.Response(jsonEncode(profileData), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileData);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    addTearDown(state.dispose);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'desktop profile uses real progress and bounded side-by-side cards',
    (tester) async {
      await open(tester, const Size(1440, 1000));
      expect(find.text('Marina Oliveira'), findsOneWidget);
      expect(find.text('7,5 km'), findsOneWidget);
      expect(find.text('64,2 km'), findsOneWidget);
      expect(find.text('10,4 km'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Corrida')).dx,
        greaterThan(tester.getCenter(find.text('Marina Oliveira')).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small phone stacks the profile and keeps edit available', (
    tester,
  ) async {
    await open(tester, const Size(320, 740));
    expect(
      tester.getTopLeft(find.text('Corrida')).dy,
      greaterThan(tester.getBottomLeft(find.text('Sua evolução')).dy),
    );
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-conta')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nome'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);
    Navigator.of(tester.element(find.text('Salvar alterações'))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('7,5 km'), 500);
    expect(find.text('7,5 km').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme menu in the app bar switches to dark mode and persists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          return http.Response(jsonEncode(progressData), 200);
        }
        return http.Response(jsonEncode(profileData), 200);
      }),
    );
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileData);
    addTearDown(api.close);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: Consumer<AppState>(
          builder: (context, state, _) => MaterialApp(
            theme: buildRunoverTheme(),
            darkTheme: buildRunoverTheme(brightness: Brightness.dark),
            themeMode: state.themeMode,
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final themeButton = find.descendant(
      of: find.byType(AppBar),
      matching: find.byTooltip('Tema do app'),
    );
    expect(themeButton, findsOneWidget);
    expect(find.text('Aparência'), findsNothing);

    await tester.tap(themeButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(state.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Marina Oliveira'))).brightness,
      Brightness.dark,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('runover_theme_mode'), 'dark');

    final reloaded = AppState(api: api);
    addTearDown(reloaded.dispose);
    await reloaded.loadThemeMode();
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable activity data is not shown as zero and can be retried',
    (tester) async {
      await open(tester, const Size(1440, 1000), failFirst: true);
      expect(
        find.text('Não foi possível carregar suas atividades.'),
        findsOneWidget,
      );
      expect(find.text('0 km'), findsNothing);
      expect(find.text('Marina Oliveira'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('7,5 km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('activity request waits until the profile is available', (
    tester,
  ) async {
    var requests = 0;
    var progressRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        requests++;
        if (request.url.path == '/runs/progress') {
          progressRequests++;
          return http.Response(jsonEncode(progressData), 200);
        }
        if (request.url.path == '/users/me') {
          return http.Response(jsonEncode(profileData), 200);
        }
        return http.Response('[]', 200);
      }),
    );
    final state = AppState(api: api);
    addTearDown(api.close);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(requests, 0);
    state.profile = UserProfile.fromJson(profileData);
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(progressRequests, 1);
    expect(find.text('7,5 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'missing progress fields stay unknown instead of invented zeroes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProfileActivity(progress: const {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('0 km'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('malformed goals and badges do not hide valid progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileActivity(
              progress: {
                ...progressData,
                'goals': [
                  null,
                  'invalid',
                  {'name': 'Incomplete'},
                  {
                    'name': 'Invalid',
                    'unit': 'km',
                    'value': double.nan,
                    'target': 10,
                  },
                  ...progressData['goals'] as List,
                ],
                'badges': [
                  null,
                  {'name': 3, 'earned': true},
                  ...progressData['badges'] as List,
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('7,5 km'), findsOneWidget);
    expect(find.text('Primeira corrida'), findsOneWidget);
    expect(find.text('Incomplete'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping avatar offers upload and remove', (tester) async {    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? patched;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          return http.Response(jsonEncode(progressData), 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/users/me') {
          patched =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({...profileData, 'photo_url': null}),
            200,
          );
        }
        if (request.url.path == '/users/me') {
          return http.Response(
            jsonEncode({
              ...profileData,
              'photo_url': 'https://example.com/foto.jpg',
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson({
        ...profileData,
        'photo_url': 'https://example.com/foto.jpg',
      });
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    expect(find.text('Alterar foto do perfil'), findsWidgets);
    expect(find.text('Carregar foto'), findsOneWidget);
    expect(find.text('Remover foto atual'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Remover foto atual'));
    await tester.pumpAndSettle();
    expect(patched?['photo_url'], isNull);
    expect(find.text('Foto removida.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openIdentity(
    WidgetTester tester, {
    Map<String, dynamic> overrides = const {},
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/runs/progress') {
          return http.Response(jsonEncode(progressData), 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson({...profileData, ...overrides});
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'identity card shows pronouns, emoticons, mural and member since',
    (tester) async {
      await openIdentity(tester, overrides: {
        'pronouns': 'ele/dele',
        'equipped_emoticons': ['🏆', '⚡'],
        'created_at': '2020-06-06T12:00:00Z',
      });
      expect(find.text('ele/dele'), findsOneWidget);
      expect(find.text('Adicionar pronomes'), findsNothing);
      expect(find.text('🏆'), findsOneWidget);
      expect(find.text('⚡'), findsOneWidget);
      expect(find.text('Membro desde 6 de jun. de 2020'), findsOneWidget);
      expect(find.text('Mural · 1'), findsOneWidget);
      // Badge aparece na atividade e no mural de conquistas.
      expect(find.text('Primeira corrida'), findsNWidgets(2));
      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.text('Loja de cosméticos'), findsOneWidget);
      expect(find.text('Insígnias'), findsOneWidget);
      expect(find.text('Mudar de conta'), findsOneWidget);
      expect(find.text('Copiar ID do usuário'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing pronouns show a placeholder that opens the editor', (
    tester,
  ) async {
    await openIdentity(tester);
    expect(find.text('Adicionar pronomes'), findsOneWidget);
    await tester.tap(find.text('Adicionar pronomes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-tab-conta')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Nome'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mudar de conta avisa antes de sair', (tester) async {
    await open(tester, const Size(390, 844));
    await tester.scrollUntilVisible(find.text('Mudar de conta'), 500);
    await tester.tap(find.text('Mudar de conta'));
    await tester.pumpAndSettle();
    expect(find.text('Mudar de conta?'), findsOneWidget);
    expect(
      find.text(
        'Você vai sair desta conta para conectar uma outra. '
        'Deseja continuar?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Sair e trocar'));
    // Sem pumpAndSettle: após o logout a tela mostra spinner infinito.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Mudar de conta?'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar mantém a conta conectada', (tester) async {
    await open(tester, const Size(390, 844));
    await tester.scrollUntilVisible(find.text('Mudar de conta'), 500);
    await tester.tap(find.text('Mudar de conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Mudar de conta?'), findsNothing);
    expect(find.text('Marina Oliveira'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
