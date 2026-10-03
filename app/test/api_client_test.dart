import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runover_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saves a failed claim and retries it with the same idempotency key',
    () async {
      var requests = 0;
      String? retriedRequestId;
      final client = ApiClient(
        client: MockClient((request) async {
          requests++;
          if (requests == 1) throw http.ClientException('offline');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          retriedRequestId = body['request_id'] as String;
          return http.Response('{"ok":true}', 200);
        }),
      );

      await expectLater(
        client.claimTerritory(
          const [],
          requestId: 'run-stable-request-001',
          userId: 'user-1',
        ),
        throwsA(isA<NetworkUnavailableException>()),
      );
      expect(await client.pendingClaimCount('user-1'), 1);

      await client.retryPendingClaims('user-1');
      expect(requests, 2);
      expect(retriedRequestId, 'run-stable-request-001');
      expect(await client.pendingClaimCount('user-1'), 0);
    },
  );

  test(
    'keeps a claim queued after a server error for a safe later retry',
    () async {
      final client = ApiClient(
        client: MockClient(
          (_) async => http.Response('{"detail":"temporary"}', 503),
        ),
      );
      await expectLater(
        client.claimTerritory(
          const [],
          requestId: 'run-server-error-001',
          userId: 'user-1',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(await client.pendingClaimCount('user-1'), 1);
    },
  );

  test('maps a slow request to a retryable network error', () async {
    final client = ApiClient(
      requestTimeout: const Duration(milliseconds: 10),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response('{}', 200);
      }),
    );
    expect(client.getMyProfile(), throwsA(isA<NetworkUnavailableException>()));
  });
}
