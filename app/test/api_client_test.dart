import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses the public host for password recovery requests', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );

    await client.requestPasswordReset('runner@example.com');
    await client.resetPassword(
      email: 'runner@example.com',
      resetCode: '123456789012',
      newPassword: 'changed456',
    );

    expect(requests[0].url.toString(), '${ApiClient.baseUrl}/auth/forgot-password');
    expect(requests[1].url.toString(), '${ApiClient.baseUrl}/auth/reset-password');
    expect(jsonDecode(requests[1].body), {
      'email': 'runner@example.com',
      'reset_code': '123456789012',
      'new_password': 'changed456',
    });
    client.close();
  });

  test('maps a slow request to a retryable network error', () async {
    final client = ApiClient(
      requestTimeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response('{}', 200);
      }),
    );
    expect(client.getMyProfile(), throwsA(isA<NetworkUnavailableException>()));
    client.close();
  });
}
