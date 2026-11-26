import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_mfa_repository.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_mfa_recovery_page.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  Finder field(String id) => find.byKey(ValueKey(id));

  Future<void> openPage(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    bool allowed = true,
  }) async {
    final api = ApiClient(MockClient(handler));

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminMfaRecoveryPage(
          repository: AdminMfaRepository(api),
          canRequestRecovery: allowed,
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String id) async {
    final finder = field(id);

    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> prepare(
    WidgetTester tester, {
    String email = 'admin@example.com',
  }) async {
    final input = field('admin-recovery-email');

    await tester.ensureVisible(input);
    await tester.enterText(input, email);

    await tap(tester, 'admin-recovery-confirm');
  }

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('Anonymous recovery access is blocked', (tester) async {
    await openPage(tester, (_) async {
      fail('Anonymous user must not reach recovery API');
    });

    expect(field('admin-recovery-denied'), findsOneWidget);

    expect(field('admin-recovery-submit'), findsNothing);

    await closePage(tester);
  });

  testWidgets('Missing recovery permission blocks form', (tester) async {
    authSession.signIn('authenticated-session');

    await openPage(tester, (_) async {
      fail('Unauthorized user must not reach recovery API');
    }, allowed: false);

    expect(field('admin-recovery-denied'), findsOneWidget);

    expect(field('admin-recovery-email'), findsNothing);

    await closePage(tester);
  });

  testWidgets('Authorized recovery uses confirmed API contract', (
    tester,
  ) async {
    authSession.signIn('supervisor-session');

    var requests = 0;

    await openPage(tester, (request) async {
      requests++;

      expect(request.method, 'POST');

      expect(request.url.path, '/api/security/admin-mfa/recovery/request');

      expect(request.headers['Authorization'], 'Bearer supervisor-session');

      expect(jsonDecode(request.body), {'adminEmail': 'admin@example.com'});

      return http.Response('', 202);
    });

    final submit = field('admin-recovery-submit');

    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await prepare(tester);

    await tap(tester, 'admin-recovery-submit');

    expect(requests, 1);

    expect(field('admin-recovery-success'), findsOneWidget);

    expect(
      tester.widget<TextField>(field('admin-recovery-email')).controller!.text,
      isEmpty,
    );

    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    expect(authSession.authenticated, isTrue);

    await closePage(tester);
  });

  testWidgets('Invalid email does not reach backend', (tester) async {
    authSession.signIn('supervisor-session');

    await openPage(tester, (_) async {
      fail('Invalid email must not reach backend');
    });

    await prepare(tester, email: 'invalid-email');

    await tap(tester, 'admin-recovery-submit');

    expect(
      find.text('Enter a valid administrator email address.'),
      findsOneWidget,
    );

    await closePage(tester);
  });

  testWidgets('Backend authorization denial is handled safely', (tester) async {
    authSession.signIn('supervisor-session');

    await openPage(tester, (_) async {
      return http.Response(
        '{"title":"PRIVATE_INTERNAL_PERMISSION_DETAILS"}',
        403,
      );
    });

    await prepare(tester);
    await tap(tester, 'admin-recovery-submit');

    expect(field('admin-recovery-error'), findsOneWidget);

    expect(field('admin-recovery-success'), findsNothing);

    expect(
      find.textContaining('PRIVATE_INTERNAL_PERMISSION_DETAILS'),
      findsNothing,
    );

    await closePage(tester);
  });

  testWidgets('Changing target email resets confirmation', (tester) async {
    authSession.signIn('supervisor-session');

    await openPage(tester, (_) async {
      fail('No recovery request expected');
    });

    await prepare(tester);

    await tester.enterText(
      field('admin-recovery-email'),
      'another@example.com',
    );

    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(field('admin-recovery-submit')).onPressed,
      isNull,
    );

    await closePage(tester);
  });

  testWidgets('Session change rejects stale recovery response', (tester) async {
    authSession.signIn('old-supervisor-session');

    final response = Completer<http.Response>();

    var requests = 0;

    await openPage(tester, (_) {
      requests++;
      return response.future;
    });

    await prepare(tester);

    final submit = field('admin-recovery-submit');

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(requests, 1);

    authSession.signIn('new-session');

    await tester.pump(const Duration(milliseconds: 300));

    response.complete(http.Response('', 202));

    await tester.pumpAndSettle();

    expect(field('admin-recovery-denied'), findsOneWidget);

    expect(field('admin-recovery-success'), findsNothing);

    expect(field('admin-recovery-email'), findsNothing);

    expect(authSession.token, 'new-session');

    await closePage(tester);
  });
}
