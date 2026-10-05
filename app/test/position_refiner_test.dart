import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/services/position_refiner.dart';

void main() {
  test('accuracy label describes the fix margin', () {
    expect(PositionRefiner.accuracyLabel(null), 'Precisão indisponível');
    expect(PositionRefiner.accuracyLabel(double.nan), 'Precisão indisponível');
    expect(PositionRefiner.accuracyLabel(0), 'Precisão indisponível');
    expect(PositionRefiner.accuracyLabel(5), 'Margem de ±5 m — excelente');
    expect(PositionRefiner.accuracyLabel(20), 'Margem de ±20 m');
    expect(
      PositionRefiner.accuracyLabel(100),
      'Sinal fraco (±100 m) — a área pode variar',
    );
    expect(
      PositionRefiner.accuracyLabel(1500),
      'Sinal fraco (±1.5 km) — a área pode variar',
    );
  });
}
