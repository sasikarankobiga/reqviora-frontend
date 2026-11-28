import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/auth/domain/auth_error_message.dart';
import 'package:reqviora_frontend/features/auth/domain/registration_result.dart';
import 'package:reqviora_frontend/features/auth/domain/verification_link.dart';

http.Response registrationResponse({
  Object? userId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
  Object? email = 'test@example.com',
  Object? displayName = 'Test User',
  Object? emailVerified = false,
  Object? verificationEmailSent = true,
}) => http.Response(
  jsonEncode({
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'emailVerified': emailVerified,
    'verificationEmailSent': verificationEmailSent,
  }),
  201,
);

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  group('Registration contract', () {
    test('HTTP 201 creates a typed result without authenticating', () async {
      var calls = 0;
      final api = ApiClient(
        MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/auth/register');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'email': 'test@example.com',
            'password': 'StrongPassword123',
            'displayName': 'Test User',
          });
          return registrationResponse();
        }),
      );
      addTearDown(api.dispose);

      final result = await AuthRepository(api).registerAccount(
        ' test@example.com ',
        'StrongPassword123',
        ' Test User ',
      );

      expect(
        result,
        const RegistrationResult(
          userId: 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
          email: 'test@example.com',
          displayName: 'Test User',
          emailVerified: false,
          verificationEmailSent: true,
        ),
      );
      expect(calls, 1);
      expect(authSession.authenticated, isFalse);
      expect(authSession.token, isNull);
      expect(authSession.refreshToken, isNull);
    });

    test('email delivery failure remains a successful registration', () async {
      final api = ApiClient(
        MockClient(
          (_) async => registrationResponse(verificationEmailSent: false),
        ),
      );
      addTearDown(api.dispose);

      final result = await AuthRepository(
        api,
      ).registerAccount('test@example.com', 'StrongPassword123', 'Test User');

      expect(result.verificationEmailSent, isFalse);
      expect(result.emailVerified, isFalse);
      expect(authSession.authenticated, isFalse);
    });

    final malformedResponses = <String, http.Response>{
      'userId': registrationResponse(userId: ''),
      'email': registrationResponse(email: 42),
      'displayName': registrationResponse(displayName: ''),
      'emailVerified': registrationResponse(emailVerified: 'false'),
      'verificationEmailSent': registrationResponse(
        verificationEmailSent: 'true',
      ),
    };

    for (final entry in malformedResponses.entries) {
      test('rejects malformed ${entry.key}', () async {
        final api = ApiClient(MockClient((_) async => entry.value));
        addTearDown(api.dispose);

        await expectLater(
          AuthRepository(api).registerAccount(
            'test@example.com',
            'StrongPassword123',
            'Test User',
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 502),
          ),
        );
        expect(authSession.authenticated, isFalse);
      });
    }

    test(
      'duplicate registration preserves HTTP 409 and makes one call',
      () async {
        var calls = 0;
        final api = ApiClient(
          MockClient((_) async {
            calls++;
            return http.Response(
              '{"title":"The email address is already registered."}',
              409,
            );
          }),
        );
        addTearDown(api.dispose);

        await expectLater(
          AuthRepository(api).registerAccount(
            'test@example.com',
            'StrongPassword123',
            'Test User',
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );

        expect(calls, 1);
        expect(authSession.authenticated, isFalse);
      },
    );

    test('concurrent registration submissions share one request', () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final api = ApiClient(
        MockClient((_) {
          calls++;
          return response.future;
        }),
      );
      addTearDown(api.dispose);
      final repository = AuthRepository(api);

      final first = repository.registerAccount(
        'test@example.com',
        'StrongPassword123',
        'Test User',
      );
      final second = repository.registerAccount(
        'test@example.com',
        'StrongPassword123',
        'Test User',
      );
      response.complete(registrationResponse());

      expect(await first, await second);
      expect(calls, 1);
    });
  });

  group('Public email verification', () {
    test('resend uses the anonymous endpoint and generic result', () async {
      var calls = 0;
      final api = ApiClient(
        MockClient((request) async {
          calls++;
          expect(
            request.url.path,
            '/api/account-security/email-verification/resend',
          );
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {'email': 'test@example.com'});
          return http.Response('', 202);
        }),
      );
      addTearDown(api.dispose);

      await AuthRepository(api).resendEmailVerification(' test@example.com ');

      expect(calls, 1);
      expect(authSession.authenticated, isFalse);
    });

    test('invalid resend email is rejected before HTTP', () async {
      var calls = 0;
      final api = ApiClient(
        MockClient((_) async {
          calls++;
          return http.Response('', 202);
        }),
      );
      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).resendEmailVerification('invalid'),
        throwsArgumentError,
      );
      expect(calls, 0);
    });

    test('HTTP 204 confirmation preserves special token characters', () async {
      const token = 'a+b/c==&safe';
      var calls = 0;
      final api = ApiClient(
        MockClient((request) async {
          calls++;
          expect(
            request.url.path,
            '/api/account-security/email-verification/confirm',
          );
          expect(jsonDecode(request.body), {'token': token});
          return http.Response('', 204);
        }),
      );
      addTearDown(api.dispose);

      await AuthRepository(api).confirmEmailVerification(token);

      expect(calls, 1);
      expect(authSession.authenticated, isFalse);
    });

    test('empty confirmation token is rejected before HTTP', () async {
      var calls = 0;
      final api = ApiClient(
        MockClient((_) async {
          calls++;
          return http.Response('', 204);
        }),
      );
      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).confirmEmailVerification('   '),
        throwsArgumentError,
      );
      expect(calls, 0);
    });

    test('invalid or expired tokens remain a safe HTTP 400', () async {
      final api = ApiClient(
        MockClient(
          (_) async => http.Response(
            '{"title":"The verification token is invalid or expired."}',
            400,
          ),
        ),
      );
      addTearDown(api.dispose);

      await expectLater(
        AuthRepository(api).confirmEmailVerification('expired-token'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
    });
  });

  test('duplicate email message is safe and actionable', () {
    final message = authErrorMessage(
      const ApiException(409, 'The email address is already registered.'),
    );
    expect(message, contains('HTTP 409'));
    expect(message, contains('sign in'));
    expect(message, isNot(contains('already registered')));
  });

  test('verification links decode tokens exactly once', () {
    expect(
      verificationTokenFromUri(
        Uri.parse('/verify-email?token=a%2Bb%2Fc%3D%3D'),
      ),
      'a+b/c==',
    );
    expect(
      verificationTokenFromUri(Uri.parse('/verify-email?token=a%252Bb')),
      'a%2Bb',
    );
  });
}
