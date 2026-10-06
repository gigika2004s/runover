import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:runover_app/services/onboarding.dart';

void main() {
  test('flag do tutorial persiste', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await OnboardingStore.seen(), isFalse);
    await OnboardingStore.markSeen();
    expect(await OnboardingStore.seen(), isTrue);
  });
}
