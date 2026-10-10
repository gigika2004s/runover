import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/services/territory_loop.dart';

Map<String, dynamic> point(
  double lat,
  double lng, {
  int segment = 0,
  double? accuracy,
}) => {
  'lat': lat,
  'lng': lng,
  'segment': segment,
  'accuracy': ?accuracy,
};

/// ~11,1 m por 0,0001 de latitude.
const step = 0.0001;

void main() {
  test('pede os pontos que faltam antes de falar de laço', () {
    final loop = TerritoryLoop.fromTrack([
      point(0, 0),
      point(step, 0),
    ]);
    expect(loop.enoughPoints, isFalse);
    expect(loop.closed, isFalse);
    expect(loop.label, contains('2 pontos de GPS'));
  });

  test('sem acurácia reportada vale o piso de 30 m', () {
    final loop = TerritoryLoop.fromTrack([
      point(0, 0),
      point(6 * step, 0),
      point(6 * step, 6 * step),
      point(0, 6 * step),
      point(5.5 * step, 0), // ~61 m do início
    ]);
    expect(loop.toleranceM, 30);
    expect(loop.closed, isFalse);
    expect(loop.remainingM, inInclusiveRange(25, 40));
    expect(loop.label, contains('Faltam ~'));
  });

  test('a incerteza dos dois pontos extremos larga o fechamento', () {
    final loop = TerritoryLoop.fromTrack([
      point(0, 0, accuracy: 50),
      point(6 * step, 0),
      point(6 * step, 6 * step),
      point(0, 6 * step),
      point(5.5 * step, 0, accuracy: 50),
    ]);
    expect(loop.toleranceM, inInclusiveRange(65, 75));
    expect(loop.closed, isTrue);
    expect(loop.label, contains('Laço fechado'));
  });

  test('a tolerância tem teto por pior que seja o sinal', () {
    final loop = TerritoryLoop.fromTrack([
      point(0, 0, accuracy: 500),
      point(6 * step, 0),
      point(6 * step, 6 * step),
      point(0, 6 * step),
      point(18 * step, 0, accuracy: 500), // ~200 m do início
    ]);
    expect(loop.toleranceM, 120);
    expect(loop.closed, isFalse);
  });

  test('retomar longe de onde parou quebra o traçado', () {
    final loop = TerritoryLoop.fromTrack([
      point(0, 0),
      point(step, 0),
      point(36 * step, 0, segment: 1), // ~400 m adiante
      point(36 * step, step, segment: 1),
    ]);
    expect(loop.brokenByPause, isTrue);
    expect(loop.closed, isFalse);
    expect(loop.label, contains('retomou'));
  });

  test('retomar no mesmo lugar mantém o laço válido', () {
    final loop = TerritoryLoop.fromTrack([
      point(0, 0),
      point(step, 0),
      point(step + step, 0, segment: 1), // ~11 m: buraco de GPS
      point(0, 0, segment: 1),
    ]);
    expect(loop.brokenByPause, isFalse);
    expect(loop.closed, isTrue);
  });
}
