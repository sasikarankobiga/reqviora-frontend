import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/application/auth_providers.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/auth/presentation/auth_page.dart';
import 'package:reqviora_frontend/features/auth/presentation/account_security_pages.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  Future<void> openPage(
    WidgetTester tester,
    Widget page,
    MockClient client,
  ) async {
    final api = ApiClient(client);
    addTearDown(api.dispose);

    await tester.binding.setSurfaceSize(const Size(1440, 1100));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository(api)),
        ],
        child: MaterialApp(home: page),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(WidgetTester tester) async {
    final email = find.byKey(const ValueKey('auth-email'));

    final password = find.byKey(const ValueKey('auth-password'));

    final button = find.byKey(const ValueKey('auth-submit'));

    expect(email, findsOneWidget);
    expect(password, findsOneWidget);
    expect(button, findsOneWidget);

    await tester.enterText(email, 'test@example.com');
    await tester.enterText(password, 'TestPassword123');

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Registration delivery failure keeps persisted success state', (
    tester,
  ) async {
    var requests = 0;
    await openPage(
      tester,
      const AuthPage(register: true),
      MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/auth/register');
        return http.Response(
          jsonEncode({
            'userId': 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
            'email': 'test@example.com',
            'displayName': 'Test User',
            'emailVerified': false,
            'verificationEmailSent': false,
          }),
          201,
        );
      }),
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-display-name')),
      'Test User',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPassword123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'StrongPassword123',
    );
    final submit = find.byKey(const ValueKey('auth-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(
      find.textContaining('Account created, but the email service'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(
      find.byKey(const ValueKey('registration-resend-link')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('registration-login-link')),
      findsOneWidget,
    );
    expect(authSession.authenticated, isFalse);
  });

  testWidgets('Server OTP challenge reveals authenticator input', (
    tester,
  ) async {
    var requests = 0;

    await openPage(
      tester,
      const AuthPage(),
      MockClient((request) async {
        requests++;

        expect(request.url.path, '/api/auth/login');

        final body = jsonDecode(request.body) as Map;

        expect(body['email'], 'test@example.com');
        expect(body.containsKey('otpCode'), isFalse);

        return http.Response('{"title":"One-time password required."}', 401);
      }),
    );

    expect(find.byKey(const ValueKey('auth-otp')), findsNothing);

    await submitLogin(tester);

    expect(requests, 1);

    expect(find.byKey(const ValueKey('auth-otp')), findsOneWidget);

    expect(authSession.authenticated, isFalse);
  });

  testWidgets('Invalid credentials do not reveal OTP input', (tester) async {
    var requests = 0;

    await openPage(
      tester,
      const AuthPage(),
      MockClient((request) async {
        requests++;

        expect(request.url.path, '/api/auth/login');

        return http.Response('{"title":"Invalid credentials."}', 401);
      }),
    );

    await submitLogin(tester);

    expect(requests, 1);

    expect(find.byKey(const ValueKey('auth-otp')), findsNothing);

    expect(authSession.authenticated, isFalse);
  });

  testWidgets('OTP challenge cannot create an authenticated session', (
    tester,
  ) async {
    await openPage(
      tester,
      const AuthPage(),
      MockClient((request) async {
        expect(request.url.path, '/api/auth/login');

        return http.Response('{"title":"One-time password required."}', 401);
      }),
    );

    await submitLogin(tester);

    expect(authSession.authenticated, isFalse);
    expect(authSession.token, isNull);
    expect(authSession.refreshToken, isNull);
  });

  testWidgets('Public verification resend is anonymous and starts cooldown', (
    tester,
  ) async {
    var requests = 0;

    await openPage(
      tester,
      const AccountSecurityPage(
        action: AccountAction.verifyEmail,
        resendCooldown: Duration(seconds: 30),
      ),
      MockClient((request) async {
        requests++;
        expect(
          request.url.path,
          '/api/account-security/email-verification/resend',
        );
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {'email': 'test@example.com'});
        return http.Response('', 202);
      }),
    );

    final email = find.byKey(const ValueKey('verification-resend-email'));
    final button = find.byKey(const ValueKey('verification-resend-submit'));

    expect(email, findsOneWidget);
    expect(button, findsOneWidget);

    await tester.enterText(email, 'test@example.com');
    await tester.tap(button);
    await tester.pump();

    expect(requests, 1);
    expect(
      find.textContaining('If an eligible account exists'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(authSession.authenticated, isFalse);
  });

  testWidgets('Public verification resend prevents duplicate submissions', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;

    await openPage(
      tester,
      const AccountSecurityPage(action: AccountAction.verifyEmail),
      MockClient((_) {
        requests++;
        return response.future;
      }),
    );

    final email = find.byKey(const ValueKey('verification-resend-email'));
    final button = find.byKey(const ValueKey('verification-resend-submit'));
    await tester.enterText(email, 'test@example.com');
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();

    expect(requests, 1);
    response.complete(http.Response('', 202));
    await tester.pump();
  });

  testWidgets('Email confirmation submits token without opening session', (
    tester,
  ) async {
    var requests = 0;

    await openPage(
      tester,
      const AccountSecurityPage(
        action: AccountAction.verifyEmail,
        token: 'test-verification-token',
      ),
      MockClient((request) async {
        requests++;

        expect(
          request.url.path,
          '/api/account-security/email-verification/confirm',
        );

        expect(jsonDecode(request.body)['token'], 'test-verification-token');

        return http.Response('', 204);
      }),
    );

    final button = find.byType(FilledButton);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(requests, 1);

    expect(find.text('Email address successfully verified.'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(button);
    await tester.pump();
    expect(requests, 1);

    expect(authSession.authenticated, isFalse);
  });

  testWidgets('Invalid confirmation token shows a safe failure state', (
    tester,
  ) async {
    await openPage(
      tester,
      const AccountSecurityPage(
        action: AccountAction.verifyEmail,
        token: 'expired-token',
      ),
      MockClient(
        (_) async => http.Response(
          '{"title":"The verification token is invalid or expired."}',
          400,
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be processed'), findsOneWidget);
    expect(find.textContaining('expired-token'), findsNothing);
  });

  testWidgets('Password reset without a token is disabled', (tester) async {
    var requests = 0;

    await openPage(
      tester,
      const AccountSecurityPage(action: AccountAction.resetPassword),
      MockClient((request) async {
        requests++;
        return http.Response('', 500);
      }),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNull);
    expect(requests, 0);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('Unauthenticated users cannot start MFA setup', (tester) async {
    var requests = 0;

    await openPage(
      tester,
      const AccountSecurityPage(action: AccountAction.setupMfa),
      MockClient((request) async {
        requests++;
        return http.Response('', 500);
      }),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(button.onPressed, isNull);
    expect(requests, 0);
    expect(authSession.authenticated, isFalse);
  });
}
