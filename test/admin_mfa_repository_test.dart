import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_mfa_repository.dart';

const token = 'abcdefghijklmnopqrstuvwxyz1234567890';
const secret = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

Map<String, dynamic> provisionResponse() => {
  'secret': secret,
  'uri':
      'otpauth://totp/REQVIORA:admin%40example.com'
      '?secret=$secret&issuer=REQVIORA',
  'recoveryCodes': List.generate(
    8,
    (index) => index.toRadixString(16).padLeft(10, '0'),
  ),
};

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  AdminMfaRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);

    return AdminMfaRepository(api);
  }

  test('Bootstrap uses confirmed enrollment endpoint', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/security/admin-mfa/bootstrap/request');

      expect(jsonDecode(request.body), {
        'email': 'admin@example.com',
        'password': 'test-password',
      });

      return http.Response('', 202);
    });

    await repo.requestBootstrap(
      email: ' admin@example.com ',
      password: 'test-password',
    );
  });

  test('Invalid bootstrap email is rejected locally', () async {
    final repo = repository((_) async {
      fail('Invalid email must not reach the API');
    });

    await expectLater(
      repo.requestBootstrap(email: 'invalid', password: 'test-password'),
      throwsArgumentError,
    );
  });

  test('Invalid bootstrap password is rejected locally', () async {
    final repo = repository((_) async {
      fail('Invalid password must not reach the API');
    });

    await expectLater(
      repo.requestBootstrap(email: 'admin@example.com', password: 'short'),
      throwsArgumentError,
    );
  });

  test('Recovery requires an authenticated session', () async {
    final repo = repository((_) async {
      fail('Anonymous recovery must not reach the API');
    });

    await expectLater(
      repo.requestRecovery(adminEmail: 'admin@example.com'),
      throwsA(isA<ApiException>()),
    );
  });

  test('Recovery sends authenticated supervisor request', () async {
    authSession.signIn('supervisor-session');

    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/security/admin-mfa/recovery/request');

      expect(request.headers['Authorization'], 'Bearer supervisor-session');

      expect(jsonDecode(request.body), {'adminEmail': 'admin@example.com'});

      return http.Response('', 202);
    });

    await repo.requestRecovery(adminEmail: 'admin@example.com');
  });

  test('Recovery preserves backend authorization rejection', () async {
    authSession.signIn('non-admin-session');

    final repo = repository((_) async {
      return http.Response('{"title":"Forbidden"}', 403);
    });

    await expectLater(
      repo.requestRecovery(adminEmail: 'admin@example.com'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Provision reads authenticator details and recovery codes', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/security/admin-mfa/provision');

      expect(jsonDecode(request.body), {'token': token});

      return http.Response(jsonEncode(provisionResponse()), 200);
    });

    final result = await repo.provision(token: token);

    expect(result.secret, secret);
    expect(result.recoveryCodes.length, 8);

    expect(() => result.recoveryCodes.add('invalid'), throwsUnsupportedError);
  });

  test('Invalid enrollment token is rejected locally', () async {
    final repo = repository((_) async {
      fail('Invalid token must not reach the API');
    });

    await expectLater(repo.provision(token: 'short'), throwsArgumentError);
  });

  test('Rejects unsafe authenticator URI', () async {
    final data = provisionResponse();

    data['uri'] = 'https://example.com/?secret=$secret';

    final repo = repository((_) async {
      return http.Response(jsonEncode(data), 200);
    });

    await expectLater(repo.provision(token: token), throwsFormatException);
  });

  test('Rejects mismatched authenticator secret', () async {
    final data = provisionResponse();

    data['uri'] =
        'otpauth://totp/REQVIORA:admin%40example.com'
        '?secret=OTHER&issuer=REQVIORA';

    final repo = repository((_) async {
      return http.Response(jsonEncode(data), 200);
    });

    await expectLater(repo.provision(token: token), throwsFormatException);
  });

  test('Rejects duplicate recovery codes', () async {
    final data = provisionResponse();

    data['recoveryCodes'] = List.filled(8, '0123456789');

    final repo = repository((_) async {
      return http.Response(jsonEncode(data), 200);
    });

    await expectLater(repo.provision(token: token), throwsFormatException);
  });

  test('Verify sends token and six-digit code', () async {
    authSession.signIn('existing-session');

    final repo = repository((request) async {
      expect(request.url.path, '/api/security/admin-mfa/verify');

      expect(jsonDecode(request.body), {'token': token, 'code': '012345'});

      return http.Response('', 204);
    });

    await repo.verify(token: token, code: '012345');

    expect(authSession.authenticated, isFalse);
  });

  test('Invalid verification code never reaches API', () async {
    final repo = repository((_) async {
      fail('Invalid OTP must not reach the API');
    });

    await expectLater(
      repo.verify(token: token, code: '12345'),
      throwsArgumentError,
    );
  });

  test('Failed verification preserves current session', () async {
    authSession.signIn('existing-session');

    final repo = repository((_) async {
      return http.Response('{"title":"Invalid credential"}', 400);
    });

    await expectLater(
      repo.verify(token: token, code: '123456'),
      throwsA(isA<ApiException>()),
    );

    expect(authSession.authenticated, isTrue);
  });

  test('Session switch rejects stale provision response', () async {
    final repo = repository((_) async {
      authSession.signIn('new-session');

      return http.Response(jsonEncode(provisionResponse()), 200);
    });

    await expectLater(
      repo.provision(token: token),
      throwsA(isA<ApiException>()),
    );
  });

  test('Stale verification cannot sign out a newer session', () async {
    authSession.signIn('old-session');

    final repo = repository((_) async {
      authSession.signIn('new-session');
      return http.Response('', 204);
    });

    await expectLater(
      repo.verify(token: token, code: '123456'),
      throwsA(isA<ApiException>()),
    );

    expect(authSession.authenticated, isTrue);
    expect(authSession.token, 'new-session');
  });
}
