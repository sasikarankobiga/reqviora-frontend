import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  test('Login retains access and refresh tokens in memory', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['otpCode'], '123456');
        return http.Response(
          jsonEncode({
            'accessToken': 'token-1',
            'refreshToken': 'refresh-1',
            'accessTokenExpiresAt': '2027-01-01T00:00:00Z',
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    await AuthRepository(
      api,
    ).signIn('demo@example.com', 'password', otpCode: '123456');
    expect(authSession.token, 'token-1');
    expect(authSession.refreshToken, 'refresh-1');
    expect(authSession.authenticated, isTrue);
  });

  test('401 triggers one refresh and retries protected GET', () async {
    var getCount = 0;
    var refreshCount = 0;
    authSession.startSession(
      accessToken: 'expired',
      refreshToken: 'old-refresh',
      accessExpiresAt: DateTime.utc(2025),
    );
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshCount++;
          expect(jsonDecode(request.body)['refreshToken'], 'old-refresh');
          return http.Response(
            jsonEncode({
              'accessToken': 'fresh',
              'refreshToken': 'new-refresh',
              'accessTokenExpiresAt': '2027-01-01T00:00:00Z',
            }),
            200,
          );
        }
        expect(request.url.path, '/api/projects');
        getCount++;
        if (request.headers['Authorization'] == 'Bearer expired') {
          return http.Response('{"title":"Expired"}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer fresh');
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.dispose);
    expect(await api.get('/api/projects'), isEmpty);
    expect(refreshCount, 1);
    expect(getCount, 2);
    expect(authSession.refreshToken, 'new-refresh');
  });

  test('Forgot password sends correct API request', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/account-security/password/forgot');
        expect(jsonDecode(request.body)['email'], 'demo@example.com');
        return http.Response('', 202);
      }),
    );
    addTearDown(api.dispose);
    await AuthRepository(api).forgotPassword(' demo@example.com ');
  });

  test('Password reset sends token and new password', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/account-security/password/reset');
        final body = jsonDecode(request.body) as Map;
        expect(body['token'], 'secret-token');
        expect(body['newPassword'], 'NewStrongPassword123');
        return http.Response('', 204);
      }),
    );
    addTearDown(api.dispose);
    await AuthRepository(
      api,
    ).resetPassword('secret-token', 'NewStrongPassword123');
  });

  test('Verification confirmation sends token', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/account-security/email-verification/confirm',
        );
        expect(jsonDecode(request.body)['token'], 'email-token');
        return http.Response('', 204);
      }),
    );
    addTearDown(api.dispose);
    await AuthRepository(api).confirmEmailVerification('email-token');
  });

  test('Verification request includes bearer credential', () async {
    authSession.signIn('session-token');
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/account-security/email-verification/request',
        );
        expect(request.headers['Authorization'], 'Bearer session-token');
        return http.Response('', 202);
      }),
    );
    addTearDown(api.dispose);
    await AuthRepository(api).requestEmailVerification();
  });

  test('MFA provisioning and verification match backend routes', () async {
    var calls = 0;
    authSession.signIn('session-token');
    final api = ApiClient(
      MockClient((request) async {
        calls++;
        if (calls == 1) {
          expect(request.url.path, '/api/security/mfa/provision');
          return http.Response(
            jsonEncode({
              'uri': 'otpauth://totp/test',
              'recoveryCodes': ['abc', 'def'],
            }),
            200,
          );
        }
        expect(request.url.path, '/api/security/mfa/verify');
        expect(jsonDecode(request.body)['code'], '123456');
        return http.Response('', 204);
      }),
    );
    addTearDown(api.dispose);
    final repository = AuthRepository(api);
    expect((await repository.provisionMfa())['recoveryCodes'], hasLength(2));
    await repository.verifyMfa('123456');
    expect(calls, 2);
  });

  test('Logout revokes refresh token and clears in-memory session', () async {
    authSession.startSession(
      accessToken: 'live',
      refreshToken: 'refresh-for-logout',
      accessExpiresAt: DateTime.utc(2027),
    );
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/auth/logout');
        expect(jsonDecode(request.body)['refreshToken'], 'refresh-for-logout');
        return http.Response('', 204);
      }),
    );
    addTearDown(api.dispose);
    await AuthRepository(api).logout();
    expect(authSession.authenticated, isFalse);
    expect(authSession.refreshToken, isNull);
  });

  test('A rejected refresh leaves the API request unauthorized', () async {
    authSession.startSession(
      accessToken: 'expired',
      refreshToken: 'invalid-refresh',
      accessExpiresAt: DateTime.utc(2025),
    );
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          return http.Response('{"title":"Refresh rejected"}', 401);
        }
        return http.Response('{"title":"Unauthorized"}', 401);
      }),
    );
    addTearDown(api.dispose);
    await expectLater(api.get('/api/projects'), throwsA(isA<ApiException>()));
    expect(authSession.authenticated, isFalse);
  });

  test('Successful reset clears the current session', () async {
    authSession.startSession(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
      accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/account-security/password/reset');
        expect(jsonDecode(request.body)['token'], 'reset-token');

        return http.Response('', 204);
      }),
    );

    addTearDown(api.dispose);

    await AuthRepository(
      api,
    ).resetPassword('reset-token', 'NewStrongPassword123');

    expect(authSession.authenticated, isFalse);
    expect(authSession.token, isNull);
    expect(authSession.refreshToken, isNull);
  });

  test('Rejected password reset preserves the current session', () async {
    authSession.signIn('existing-session');

    final generation = authSession.generation;

    final api = ApiClient(
      MockClient((request) async {
        return http.Response('{"title":"Invalid or expired reset token"}', 400);
      }),
    );

    addTearDown(api.dispose);

    await expectLater(
      AuthRepository(
        api,
      ).resetPassword('expired-token', 'NewStrongPassword123'),
      throwsA(isA<ApiException>()),
    );

    expect(authSession.token, 'existing-session');
    expect(authSession.generation, generation);
  });

  test('Stale password reset cannot clear a newer session', () async {
    authSession.signIn('old-session');

    final api = ApiClient(
      MockClient((request) async {
        authSession.signIn('new-session');

        return http.Response('', 204);
      }),
    );

    addTearDown(api.dispose);

    try {
      await AuthRepository(
        api,
      ).resetPassword('reset-token', 'NewStrongPassword123');
    } on ApiException {
      // ApiClient may reject a response belonging to an old session.
    }

    expect(authSession.authenticated, isTrue);
    expect(authSession.token, 'new-session');
  });

  test('Empty password reset token never reaches the API', () async {
    final api = ApiClient(
      MockClient((request) async {
        fail('Invalid reset token must not reach the API');
      }),
    );

    addTearDown(api.dispose);

    await expectLater(
      AuthRepository(api).resetPassword('   ', 'NewStrongPassword123'),
      throwsArgumentError,
    );
  });
}
