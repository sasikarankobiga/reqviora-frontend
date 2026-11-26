import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';

http.Response loginResponse({
  Object accessToken = 'valid-access',
  String refreshToken = 'valid-refresh',
  bool expired = false,
}) {
  return http.Response(
    jsonEncode({
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt':
          DateTime.now()
              .toUtc()
              .add(Duration(hours: expired ? -1 : 1))
              .toIso8601String(),
    }),
    200,
  );
}

void startSession(String name) {
  authSession.startSession(
    accessToken: '$name-access',
    refreshToken: '$name-refresh',
    accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  group('Authentication repository safety', () {
    test('Invalid access token data type is rejected', () async {
      final api = ApiClient(
        MockClient((request) async {
          return loginResponse(accessToken: 12345);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).signIn('user@example.com', 'TestPassword123'),
        throwsA(isA<ApiException>()),
      );

      expect(authSession.authenticated, isFalse);
    });

    test('Blank access token is rejected', () async {
      final api = ApiClient(
        MockClient((request) async {
          return loginResponse(accessToken: '   ');
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).signIn('user@example.com', 'TestPassword123'),
        throwsA(isA<ApiException>()),
      );

      expect(authSession.authenticated, isFalse);
    });

    test('Expired login credentials are rejected', () async {
      final api = ApiClient(
        MockClient((request) async {
          return loginResponse(expired: true);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).signIn('user@example.com', 'TestPassword123'),
        throwsA(isA<ApiException>()),
      );

      expect(authSession.authenticated, isFalse);
    });

    test('Latest login attempt wins', () async {
      final firstStarted = Completer<void>();
      final firstResponse = Completer<http.Response>();

      final api = ApiClient(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map;

          if (body['email'] == 'first@example.com') {
            firstStarted.complete();
            return firstResponse.future;
          }

          return loginResponse(
            accessToken: 'second-access',
            refreshToken: 'second-refresh',
          );
        }),
      );

      addTearDown(api.dispose);

      final repository = AuthRepository(api);

      final first = repository.signIn('first@example.com', 'TestPassword123');

      final verification = expectLater(first, throwsA(isA<ApiException>()));

      await firstStarted.future;

      await repository.signIn('second@example.com', 'TestPassword123');

      firstResponse.complete(
        loginResponse(
          accessToken: 'first-access',
          refreshToken: 'first-refresh',
        ),
      );

      await verification;

      expect(authSession.token, 'second-access');
      expect(authSession.refreshToken, 'second-refresh');
    });

    test('Delayed logout cannot clear a new session', () async {
      startSession('first');

      final logoutStarted = Completer<void>();
      final logoutResponse = Completer<http.Response>();

      final api = ApiClient(
        MockClient((request) async {
          expect(request.url.path, '/api/auth/logout');

          final body = jsonDecode(request.body) as Map;

          expect(body['refreshToken'], 'first-refresh');

          logoutStarted.complete();

          return logoutResponse.future;
        }),
      );

      addTearDown(api.dispose);

      final pending = AuthRepository(api).logout();

      final verification = expectLater(pending, throwsA(isA<ApiException>()));

      await logoutStarted.future;

      startSession('second');

      logoutResponse.complete(http.Response('', 204));

      await verification;

      expect(authSession.authenticated, isTrue);
      expect(authSession.token, 'second-access');
      expect(authSession.refreshToken, 'second-refresh');
    });

    test('Failed logout still clears local credentials', () async {
      startSession('first');

      final api = ApiClient(
        MockClient((request) async {
          throw http.ClientException('Connection failed');
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).logout(),
        throwsA(isA<ApiException>()),
      );

      expect(authSession.authenticated, isFalse);
      expect(authSession.token, isNull);
      expect(authSession.refreshToken, isNull);
    });
  });
}
