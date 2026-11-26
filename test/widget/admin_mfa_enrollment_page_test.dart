import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_mfa_repository.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_mfa_enrollment_page.dart';

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

  Finder field(String key) => find.byKey(ValueKey(key));

  Future<void> openPage(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    VoidCallback? onReturn,
  }) async {
    final api = ApiClient(MockClient(handler));

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMfaEnrollmentPage(
          repository: AdminMfaRepository(api),
          onReturnToSignIn: onReturn ?? () {},
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(field(key));
    await tester.tap(field(key));
    await tester.pumpAndSettle();
  }

  Future<void> provision(WidgetTester tester) async {
    final input = field('admin-enrollment-token');

    await tester.ensureVisible(input);
    await tester.enterText(input, token);

    await tap(tester, 'admin-provision-request');
  }

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('Bootstrap submits credentials securely', (tester) async {
    var requests = 0;

    await openPage(tester, (request) async {
      requests++;

      expect(request.url.path, '/api/security/admin-mfa/bootstrap/request');

      expect(jsonDecode(request.body), {
        'email': 'admin@example.com',
        'password': 'test-password',
      });

      return http.Response('', 202);
    });

    await tester.enterText(
      field('admin-enrollment-email'),
      'admin@example.com',
    );

    await tester.enterText(field('admin-enrollment-password'), 'test-password');

    await tap(tester, 'admin-bootstrap-request');

    expect(requests, 1);

    expect(
      find.text('If eligible, enrollment instructions will be sent securely.'),
      findsOneWidget,
    );

    final password = tester.widget<TextField>(
      field('admin-enrollment-password'),
    );

    expect(password.controller!.text, isEmpty);
    expect(password.obscureText, isTrue);

    await closePage(tester);
  });

  testWidgets('Enrollment requires recovery confirmation before verification', (
    tester,
  ) async {
    var verifications = 0;
    var returned = false;

    await openPage(tester, (request) async {
      if (request.url.path.endsWith('/provision')) {
        expect(jsonDecode(request.body), {'token': token});

        return http.Response(jsonEncode(provisionResponse()), 200);
      }

      if (request.url.path.endsWith('/verify')) {
        verifications++;

        expect(jsonDecode(request.body), {'token': token, 'code': '123456'});

        return http.Response('', 204);
      }

      fail('Unexpected API request');
    }, onReturn: () => returned = true);

    await provision(tester);

    expect(field('admin-enrollment-secret'), findsOneWidget);

    final verify = field('admin-enrollment-verify');

    await tester.ensureVisible(verify);

    expect(tester.widget<FilledButton>(verify).onPressed, isNull);

    await tap(tester, 'admin-recovery-confirmation');

    final code = field('admin-enrollment-code');

    await tester.ensureVisible(code);
    await tester.enterText(code, '123456');

    await tap(tester, 'admin-enrollment-verify');

    expect(verifications, 1);

    expect(field('admin-enrollment-secret'), findsNothing);

    expect(field('admin-enrollment-recovery-codes'), findsNothing);

    expect(
      find.text('Administrator MFA verification completed.'),
      findsOneWidget,
    );

    await tap(tester, 'admin-enrollment-return');

    expect(returned, isTrue);

    await closePage(tester);
  });

  testWidgets('Backend errors do not expose raw response', (tester) async {
    await openPage(tester, (_) async {
      return http.Response('{"title":"PRIVATE_INTERNAL_RESPONSE"}', 400);
    });

    await provision(tester);

    expect(
      find.text('Unable to provision MFA. Check your enrollment credential.'),
      findsOneWidget,
    );

    expect(find.textContaining('PRIVATE_INTERNAL_RESPONSE'), findsNothing);

    final credential = tester.widget<TextField>(
      field('admin-enrollment-token'),
    );

    expect(credential.controller!.text, isEmpty);

    await closePage(tester);
  });

  testWidgets('Session change removes sensitive enrollment data', (
    tester,
  ) async {
    await openPage(tester, (_) async {
      return http.Response(jsonEncode(provisionResponse()), 200);
    });

    await provision(tester);

    expect(field('admin-enrollment-secret'), findsOneWidget);

    authSession.signIn('new-session');

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(field('admin-enrollment-secret'), findsNothing);

    expect(field('admin-enrollment-recovery-codes'), findsNothing);

    expect(
      find.text('The session changed. Return to sign in.'),
      findsOneWidget,
    );

    await closePage(tester);
  });

  testWidgets('Authenticated session cannot open signed-out enrollment', (
    tester,
  ) async {
    authSession.signIn('existing-session');

    await openPage(tester, (_) async {
      fail('Blocked enrollment must not reach the API');
    });

    expect(field('admin-bootstrap-request'), findsNothing);

    expect(field('admin-provision-request'), findsNothing);

    expect(
      find.text('The session changed. Return to sign in.'),
      findsOneWidget,
    );

    await closePage(tester);
  });
}
