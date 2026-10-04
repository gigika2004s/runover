import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:runover_app/screens/map_screen.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:runover_app/state/app_state.dart';

class FakeGeolocation extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;
  Position position = fix(accuracy: 1500);
  Object? error;
  int requests = 0;
  LocationSettings? requestedSettings;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requests++;
    requestedSettings = locationSettings;
    if (error != null) throw error!;
    return position;
  }
}

Position fix({required double accuracy, double lat = -23.7, DateTime? time}) =>
    Position(
      longitude: -46.7,
      latitude: lat,
      timestamp: time ?? DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late GeolocatorPlatform original;
  late FakeGeolocation geo;
  late ApiClient api;

  setUp(() {
    original = GeolocatorPlatform.instance;
    geo = FakeGeolocation();
    GeolocatorPlatform.instance = geo;
    api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/territories') return http.Response('[]', 200);
        if (request.url.path == '/location') return http.Response('', 204);
        return http.Response('{"detail":"Sessão de teste"}', 401);
      }),
    );
  });

  tearDown(() {
    GeolocatorPlatform.instance = original;
    api.close();
  });

  Future<void> openMap(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(api: api),
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('coarse location displays uncertainty in meters on the map', (
    tester,
  ) async {
    await openMap(tester);
    expect(
      find.textContaining('Localização aproximada: margem informada de 1.5 km'),
      findsOneWidget,
    );
    final circle = tester
        .widget<CircleLayer>(find.byType(CircleLayer))
        .circles
        .single;
    expect(circle.radius, 1500);
    expect(circle.useRadiusInMeter, isTrue);
    expect(geo.requestedSettings!.accuracy, LocationAccuracy.best);
    expect(geo.requestedSettings!.timeLimit, const Duration(seconds: 15));
  });

  testWidgets('fresh location replaces the old point, circle and camera', (
    tester,
  ) async {
    await openMap(tester);
    geo.position = fix(accuracy: 12, lat: -23.6);
    await tester.tap(find.byTooltip('Atualizar localização'));
    await tester.pumpAndSettle();
    expect(geo.requests, 2);
    expect(
      find.text('Localização estimada: margem informada de 12 m.'),
      findsOneWidget,
    );
    final circle = tester
        .widget<CircleLayer>(find.byType(CircleLayer))
        .circles
        .single;
    expect(circle.radius, 12);
    expect(circle.point.latitude, -23.6);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center.latitude, -23.6);
  });

  testWidgets('denied permission is explained without placing a user marker', (
    tester,
  ) async {
    geo.permission = LocationPermission.deniedForever;
    await openMap(tester);
    expect(
      find.textContaining('Permita o acesso à localização'),
      findsOneWidget,
    );
    expect(geo.requests, 0);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets(
    'failed refresh removes the old point and offers another attempt',
    (tester) async {
      await openMap(tester);
      geo.error = TimeoutException('timeout');
      await tester.tap(find.byTooltip('Atualizar localização'));
      await tester.pumpAndSettle();
      expect(find.textContaining('A localização demorou'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        isEmpty,
      );
      expect(find.byType(CircleLayer), findsNothing);
      geo.error = null;
      await tester.tap(find.byTooltip('Atualizar localização'));
      await tester.pumpAndSettle();
      expect(find.byType(CircleLayer), findsOneWidget);
    },
  );

  testWidgets('unknown accuracy is not presented as a precise fix', (
    tester,
  ) async {
    geo.position = fix(accuracy: 0);
    await openMap(tester);
    expect(find.textContaining('não informou a precisão'), findsOneWidget);
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('old fixes do not appear as the current position', (
    tester,
  ) async {
    geo.position = fix(
      accuracy: 10,
      time: DateTime.now().subtract(const Duration(minutes: 3)),
    );
    await openMap(tester);
    expect(
      find.textContaining('posição recebida está desatualizada'),
      findsOneWidget,
    );
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
  });
}
