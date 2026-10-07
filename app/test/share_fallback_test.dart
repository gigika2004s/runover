import 'package:flutter_test/flutter_test.dart';
import 'package:runover_app/services/data_export_share.dart';

void main() {
  test('sem plataforma, relata falha em vez de travar', () async {
    final ok = await shareExportedJson('a.json', '{"a":1}').timeout(
      const Duration(seconds: 10),
    );
    expect(ok, isFalse);
  });
}
