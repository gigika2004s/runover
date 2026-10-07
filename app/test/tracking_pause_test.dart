import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/screens/tracking_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';
import 'package:runover_app/theme.dart';

import 'profile_screen_test.dart' show profileData;

class _FakeGeo extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      _fix();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream.empty();
}

Position _fix() => Position(
  longitude: -46.8523,
  latitude: -23.6489,
  timestamp: DateTime.now(),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late GeolocatorPlatform original;

  setUp(() {
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = _FakeGeo();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
  });
  tearDown(() {
    GeolocatorPlatform.instance = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
  });

  Map<String, dynamic> draftJson() => {
    'id': '11111111-1111-4111-8111-111111111111',
    'track': [
      for (var i = 0; i < 3; i++)
        {
          'lat': -23.6489,
          'lng': -46.8523 + i * 0.0001,
          'timestamp': DateTime.now()
              .subtract(Duration(minutes: 3 - i))
              .toIso8601String(),
          'segment': 0,
        },
    ],
    'name': '',
    'segment': 0,
    'queued': false,
    'conquer': true,
    'challenge': 'pace',
    'team_id': null,
  };

  Future<void> open(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'runover_drafts_profile-test': jsonEncode([draftJson()]),
    });
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/teams/mine') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/territories') {
          return http.Response('[]', 200);
        }
        if (request.url.path == '/territories/wild') {
          return http.Response(
            jsonEncode([
              {
                'key': 'w1',
                'center': {'lat': -23.6489, 'lng': -46.8523},
                'radius_m': 100,
                'relevance': 1,
                'rarity': 'comum',
                'spawned_at': '2026-10-06T00:00:00Z',
                'expires_at': '2026-10-07T00:00:00Z',
              },
            ]),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);
    final state = AppState(api: api)
      ..profile = UserProfile.fromJson(profileData)
      ..status = AuthStatus.signedIn;
    addTearDown(state.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildRunoverTheme(),
          home: const TrackingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pausar com conquista avisa antes', (tester) async {
    await open(tester);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Pausar'), findsOneWidget);

    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();
    expect(find.text('Pausar corrida?'), findsOneWidget);
    expect(
      find.textContaining('Para valer de verdade'),
      findsOneWidget,
    );

    await tester.tap(find.text('Pausar mesmo assim'));
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
    await tester.pumpAndSettle();
    expect(find.text('Pausar corrida?'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.textContaining('Pausas (1): manual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('continuar correndo dispensa o aviso', (tester) async {
    await open(tester);
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar correndo'));
    await tester.pumpAndSettle();
    expect(find.text('Pausar corrida?'), findsNothing);
    expect(find.text('Pausar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
