import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/auth/domain/auth_error_message.dart';

http.Response registrationResponse({
  Object accessToken = 'registration-access',
  bool expired = false,
}) {
  return http.Response(
    jsonEncode({
      'userId': 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
      'email': 'test@example.com',
      'displayName': 'Test User',
      'accessToken': accessToken,
      'accessTokenExpiresAt':
          DateTime.now()
              .toUtc()
              .add(Duration(hours: expired ? -1 : 1))
              .toIso8601String(),
      'refreshToken': 'registration-refresh',
      'refreshTokenExpiresAt':
          DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
      'tokenType': 'Bearer',
    }),
    201,
  );
}

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  group('Registration verification', () {
    test('Retry does not create another account', () async {
      var registrations = 0;
      var verificationRequests = 0;

      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/register') {
            registrations++;
            return registrationResponse();
          }

          expect(
            request.url.path,
            '/api/account-security/email-verification/request',
          );

          expect(
            request.headers['Authorization'],
            'Bearer registration-access',
          );

          verificationRequests++;

          if (verificationRequests == 1) {
            return http.Response('{}', 503);
          }

          return http.Response('', 202);
        }),
      );

      addTearDown(api.dispose);

      final repository = AuthRepository(api);

      RegistrationVerificationPending? pending;

      try {
        await repository.registerAccount(
          'test@example.com',
          'StrongPassword123',
          'Test User',
        );
      } on RegistrationVerificationPending catch (error) {
        pending = error;
      }

      expect(pending, isNotNull);

      final retry = pending!;

      expect(retry.canRetry, isTrue);

      await repository.retryRegistrationVerification(retry);

      expect(registrations, 1);
      expect(verificationRequests, 2);
      expect(retry.canRetry, isFalse);
      expect(authSession.authenticated, isFalse);
    });

    test('Session change invalidates registration retry', () async {
      var calls = 0;

      final api = ApiClient(
        MockClient((request) async {
          calls++;

          if (request.url.path == '/api/auth/register') {
            return registrationResponse();
          }

          return http.Response('{}', 503);
        }),
      );

      addTearDown(api.dispose);

      final repository = AuthRepository(api);

      RegistrationVerificationPending? pending;

      try {
        await repository.registerAccount(
          'test@example.com',
          'StrongPassword123',
          'Test User',
        );
      } on RegistrationVerificationPending catch (error) {
        pending = error;
      }

      expect(pending, isNotNull);

      final retry = pending!;

      authSession.signIn('another-session');

      expect(retry.canRetry, isFalse);

      await expectLater(
        repository.retryRegistrationVerification(retry),
        throwsA(isA<ApiException>()),
      );

      expect(calls, 2);
      expect(authSession.token, 'another-session');
    });

    test('Expired retry credentials are rejected locally', () async {
      final pending = RegistrationVerificationPending(
        accessToken: 'expired-registration-token',
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        generation: authSession.generation,
      );

      var calls = 0;

      final api = ApiClient(
        MockClient((request) async {
          calls++;
          return http.Response('', 202);
        }),
      );

      addTearDown(api.dispose);

      expect(pending.canRetry, isFalse);

      await expectLater(
        AuthRepository(api).retryRegistrationVerification(pending),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            410,
          ),
        ),
      );

      expect(calls, 0);
      expect(authSession.authenticated, isFalse);
    });

    test('Cleared registration credential cannot be reused', () async {
      final pending = RegistrationVerificationPending(
        accessToken: 'temporary-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        generation: authSession.generation,
      );

      expect(pending.canRetry, isTrue);

      pending.clear();

      expect(pending.canRetry, isFalse);
    });

    for (final status in [202, 204]) {
      test('Verification HTTP $status completes registration', () async {
        final calls = <String>[];

        final api = ApiClient(
          MockClient((request) async {
            calls.add(request.url.path);

            expect(request.method, 'POST');

            if (request.url.path == '/api/auth/register') {
              final body = jsonDecode(request.body) as Map;

              expect(body['email'], 'test@example.com');
              expect(body['displayName'], 'Test User');
              expect(body['password'], 'StrongPassword123');

              expect(request.headers['Authorization'], isNull);

              return registrationResponse();
            }

            expect(
              request.url.path,
              '/api/account-security/email-verification/request',
            );

            expect(
              request.headers['Authorization'],
              'Bearer registration-access',
            );

            expect(authSession.authenticated, isFalse);
            expect(authSession.refreshToken, isNull);

            return http.Response('', status);
          }),
        );

        addTearDown(api.dispose);

        await AuthRepository(api).registerAccount(
          ' test@example.com ',
          'StrongPassword123',
          ' Test User ',
        );

        expect(calls, [
          '/api/auth/register',
          '/api/account-security/email-verification/request',
        ]);

        expect(authSession.authenticated, isFalse);
        expect(authSession.token, isNull);
        expect(authSession.refreshToken, isNull);
      });
    }

    test('Registration failure does not request verification', () async {
      var calls = 0;

      final api = ApiClient(
        MockClient((request) async {
          calls++;

          expect(request.url.path, '/api/auth/register');

          return http.Response('{"title":"Registration failed"}', 409);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(
          api,
        ).registerAccount('test@example.com', 'StrongPassword123', 'Test User'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );

      expect(calls, 1);
      expect(authSession.authenticated, isFalse);
    });

    test('Invalid registration token is rejected', () async {
      var calls = 0;

      final api = ApiClient(
        MockClient((request) async {
          calls++;
          return registrationResponse(accessToken: 12345);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(
          api,
        ).registerAccount('test@example.com', 'StrongPassword123', 'Test User'),
        throwsA(isA<ApiException>()),
      );

      expect(calls, 1);
      expect(authSession.authenticated, isFalse);
    });

    test('Expired registration token is rejected', () async {
      var calls = 0;

      final api = ApiClient(
        MockClient((request) async {
          calls++;
          return registrationResponse(expired: true);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(
          api,
        ).registerAccount('test@example.com', 'StrongPassword123', 'Test User'),
        throwsA(isA<ApiException>()),
      );

      expect(calls, 1);
      expect(authSession.authenticated, isFalse);
    });

    test('Email service failure preserves account creation status', () async {
      var calls = 0;

      final api = ApiClient(
        MockClient((request) async {
          calls++;

          if (request.url.path == '/api/auth/register') {
            return registrationResponse();
          }

          return http.Response('{"title":"Email delivery unavailable"}', 503);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(
          api,
        ).registerAccount('test@example.com', 'StrongPassword123', 'Test User'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 424)),
      );

      expect(calls, 2);
      expect(authSession.authenticated, isFalse);
    });

    test('Unexpected verification response is rejected', () async {
      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/register') {
            return registrationResponse();
          }

          return http.Response('{}', 200);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(
          api,
        ).registerAccount('test@example.com', 'StrongPassword123', 'Test User'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 424)),
      );

      expect(authSession.authenticated, isFalse);
    });

    test('Verification failure message prevents duplicate registration', () {
      final message = authErrorMessage(
        const ApiException(424, 'Verification request failed'),
      );

      expect(message, contains('account was created'));
      expect(message, contains('Do not register again'));
      expect(message, contains('Check your inbox'));
    });
  });
}
