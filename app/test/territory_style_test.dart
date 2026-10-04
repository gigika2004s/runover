import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/models.dart';
import 'package:runover_app/theme.dart';
import 'package:runover_app/widgets/territory_style.dart';

Territory _t(
  String id,
  String? owner, {
  double lat = 0,
  double lng = 0,
  int takeovers = 0,
  String type = 'user',
}) => Territory(
  id: id,
  name: id,
  coordinates: [
    LatLngPoint(lat - .001, lng - .001),
    LatLngPoint(lat - .001, lng + .001),
    LatLngPoint(lat + .001, lng + .001),
    LatLngPoint(lat + .001, lng - .001),
  ],
  center: LatLngPoint(lat, lng),
  radiusM: 100,
  status: owner == null ? 'disponivel' : 'conquistado',
  ownerType: owner == null ? null : type,
  ownerDisplay: owner,
  takeovers: takeovers,
);

void main() {
  test('polygonContains detects points inside the ring', () {
    final t = _t('a', 'x');
    expect(polygonContains(t.coordinates, 0, 0), isTrue);
    expect(polygonContains(t.coordinates, .01, 0), isFalse);
  });

  test('territoryColor keeps own color and a stable color per rival', () {
    expect(
      territoryColor(_t('a', 'me'), myUsername: 'me'),
      RunoverColors.territory,
    );
    expect(
      territoryColor(_t('a', 'rival'), myUsername: 'me'),
      territoryColor(_t('b', 'rival'), myUsername: 'me'),
    );
    expect(rivalPalette, contains(territoryColor(_t('a', 'rival'))));
    expect(isRivalTerritory(_t('a', null), myUsername: 'me'), isFalse);
  });

  test('disputeHeat grows with takeovers and nearby owners', () {
    final calm = _t('a', 'x');
    final busy = _t('b', 'y', takeovers: 2);
    final neighbour = _t('c', 'z', lng: .002);
    final far = _t('d', 'w', lat: 1);
    expect(disputeHeat(calm, [calm, far]), 0);
    expect(disputeHeat(_t('f', null), [calm]), 0);
    expect(disputeHeat(busy, [busy, neighbour]), .75);
  });
}
