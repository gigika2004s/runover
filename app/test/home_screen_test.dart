import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/home_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('map tab opens on a light start screen without loading the map', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var territoryRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.startsWith('/territories')) territoryRequests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson({
        'id': '1',
        'full_name': 'Marina Oliveira',
        'username': 'marina',
        'email': 'marina@example.com',
        'photo_url': null,
        'total_score': 0,
        'territories_count': 0,
        'rank_position': null,
        'team_name': null,
        'level': 1,
        'level_progress': 0,
        'points_to_next_level': 100,
        'is_public': true,
        'play_seconds': 0,
      });
    addTearDown(state.dispose);
    var menuOpened = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: HomeScreen(onOpenMenu: () => menuOpened = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar corrida'), findsOneWidget);
    expect(find.text('Ver mapa de territórios'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(territoryRequests, 0);

    await tester.tap(find.byTooltip('Menu'));
    expect(menuOpened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
