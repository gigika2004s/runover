import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runover_app/widgets/location_gate.dart';

class _FakeGeo extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  bool serviceOn = true;
  Object? checkError;
  Object? requestError;
  int settingsOpened = 0;

  @override
  Future<bool> isLocationServiceEnabled() async {
    if (checkError != null) throw checkError!;
    return serviceOn;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    if (checkError != null) throw checkError!;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    if (requestError != null) throw requestError!;
    return permission = LocationPermission.whileInUse;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  late _FakeGeo geo;
  late GeolocatorPlatform original;

  setUp(() {
    geo = _FakeGeo();
    original = GeolocatorPlatform.instance;
    GeolocatorPlatform.instance = geo;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  Future<void> pumpGate(WidgetTester tester, VoidCallback onGranted) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LocationGate(onGranted: onGranted))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pede permissao no toque e libera', (tester) async {
    var granted = 0;
    await pumpGate(tester, () => granted++);
    expect(find.text('Ativar localização'), findsWidgets);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Ativar localização'),
    );
    await tester.pumpAndSettle();
    expect(granted, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('negada permanente mostra configuracoes', (tester) async {
    geo.permission = LocationPermission.deniedForever;
    await pumpGate(tester, () {});
    expect(find.text('Permissão negada'), findsOneWidget);
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
    expect(geo.settingsOpened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gps desligado pede para ativar e tenta de novo', (tester) async {
    geo.serviceOn = false;
    var granted = 0;
    await pumpGate(tester, () => granted++);
    expect(find.text('GPS desligado'), findsOneWidget);

    geo.serviceOn = true;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    // Serviço ok + permissão negada: volta ao pedido por gesto.
    expect(find.text('Ativar localização'), findsWidgets);
    expect(granted, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha exibe erro sem travar e permite retry', (tester) async {
    geo.checkError = Exception('falha simulada');
    await pumpGate(tester, () {});
    expect(find.text('Falha na localização'), findsOneWidget);

    geo.checkError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ativar localização'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro no pedido nao trava o botao', (tester) async {
    geo.requestError = Exception('prompt bloqueado');
    var granted = 0;
    await pumpGate(tester, () => granted++);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Ativar localização'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Falha na localização'), findsOneWidget);
    expect(granted, 0);

    geo.requestError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Ativar localização'),
    );
    await tester.pumpAndSettle();
    expect(granted, 1);
    expect(tester.takeException(), isNull);
  });
}
