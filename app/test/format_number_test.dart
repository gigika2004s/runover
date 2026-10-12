import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/format.dart';

void main() {
  test('formatNumber não deixa zero sobrando nem mostra resíduo de divisão', () {
    // Inteiro não leva zero: `4.0` é "4".
    expect(formatNumber(4.0), '4');
    // `4800 / 1000` dá 4.8, mas `3960 / 1000` é 4 para a pessoa — não "4,0".
    expect(formatNumber(3.96), '4');
    expect(formatNumber(4.8), '4,8');
    expect(formatNumber(12.34), '12,3');
    expect(formatNumber(7), '7');
    // Arredondar para cima pode levar a centena cheia.
    expect(formatNumber(99.96), '100');
  });

  test('formatPoints separa milhares', () {
    expect(formatPoints(999), '999');
    expect(formatPoints(1000), '1.000');
    expect(formatPoints(12345678), '12.345.678');
  });
}
