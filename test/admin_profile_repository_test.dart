import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_profile_repository.dart';

const adminId = '11111111-1111-4111-8111-111111111111';
const sessionId = '22222222-2222-4222-8222-222222222222';

Map<String, Object?> profile({String name = 'Varmitha'}) => {
  'id': adminId,
  'email': 'admin@example.com',
  'displayName': name,
  'emailVerified': true,
  'mfaEnabled': true,
  'role': 'must-not-be-read',
};

void main() {
  setUp(() => authSession.signIn('admin-token'));
  tearDown(authSession.signOut);

  test(
    'parses authorized profile fields and ignores role escalation data',
    () async {
      final api = ApiClient(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/admin/profile');
          return http.Response(jsonEncode(profile()), 200);
        }),
      );
      addTearDown(api.dispose);
      final result = await AdminProfileRepository(api).profile();
      expect(result.id, adminId);
      expect(result.displayName, 'Varmitha');
      expect(result.toString(), isNot(contains('must-not-be-read')));
    },
  );

  test(
    'updates only normalized display name with server confirmation',
    () async {
      final api = ApiClient(
        MockClient((request) async {
          expect(request.method, 'PUT');
          expect(jsonDecode(request.body), {'displayName': 'New Name'});
          return http.Response(jsonEncode(profile(name: 'New Name')), 200);
        }),
      );
      addTearDown(api.dispose);
      expect(
        (await AdminProfileRepository(
          api,
        ).updateDisplayName(' New Name ')).displayName,
        'New Name',
      );
    },
  );

  test('invalid profile input never reaches backend', () async {
    var calls = 0;
    final api = ApiClient(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.dispose);
    expect(
      () => AdminProfileRepository(api).updateDisplayName('   '),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('loads security, active sessions and paged login history', () async {
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/security')) {
          return http.Response(
            jsonEncode({
              'mfaEnabled': true,
              'emailVerified': true,
              'activeSessions': 1,
              'recentEvents': [],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/sessions')) {
          return http.Response(
            jsonEncode([
              {
                'id': sessionId,
                'createdAt': '2026-11-20T10:00:00Z',
                'expiresAt': '2026-12-20T10:00:00Z',
                'isCurrent': true,
                'refreshToken': 'never-retain',
              },
            ]),
            200,
          );
        }
        expect(request.url.queryParameters, containsPair('page', '2'));
        return http.Response(
          jsonEncode([
            {
              'id': adminId,
              'ipAddress': '192.0.2.10',
              'deviceId': 'browser-device',
              'succeeded': true,
              'otpRequired': true,
              'occurredAt': '2026-11-20T10:00:00Z',
            },
          ]),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final repository = AdminProfileRepository(api);
    expect((await repository.security()).activeSessions, 1);
    expect((await repository.sessions()).single.isCurrent, isTrue);
    expect((await repository.loginHistory(page: 2)).single.otpRequired, isTrue);
  });

  test('revokes selected and other sessions using actual endpoints', () async {
    var calls = 0;
    final api = ApiClient(
      MockClient((request) async {
        calls++;
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/admin/profile/sessions/$sessionId');
          return http.Response('', 204);
        }
        expect(request.url.path, '/api/admin/profile/sessions/revoke-others');
        return http.Response('{"revoked":2}', 200);
      }),
    );
    addTearDown(api.dispose);
    final repository = AdminProfileRepository(api);
    await repository.revokeSession(sessionId);
    expect(await repository.revokeOtherSessions(), 2);
    expect(calls, 2);
  });

  test(
    'stale profile response cannot cross account session boundary',
    () async {
      final response = Completer<http.Response>();
      final api = ApiClient(MockClient((_) => response.future));
      addTearDown(api.dispose);
      final pending = AdminProfileRepository(api).profile();
      authSession.signOut();
      authSession.signIn('different-account-token');
      response.complete(http.Response(jsonEncode(profile()), 200));
      await expectLater(
        pending,
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    },
  );

  test('unauthorized profile response is not treated as data', () async {
    final api = ApiClient(MockClient((_) async => http.Response('{}', 403)));
    addTearDown(api.dispose);
    await expectLater(
      AdminProfileRepository(api).profile(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });
}
