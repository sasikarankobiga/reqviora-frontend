import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:flutter/material.dart';
import 'package:reqviora_frontend/l10n/app_localizations.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/administration/presentation/pages/admin_dashboard_page.dart';

void main() {
  testWidgets('Admin dashboard supports Tamil locale', (tester) async {
    authSession.signIn('localization-test-token');
    addTearDown(authSession.signOut);

    await tester.binding.setSurfaceSize(const Size(1440, 900));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('ta'),
          supportedLocales: supportedAppLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: AdminDashboardPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('\u0BA8\u0BBF\u0BB0\u0BCD\u0BB5\u0BBE\u0B95\u0BAE\u0BCD'),
      findsOneWidget,
    );

    expect(find.text('Administration'), findsNothing);
    expect(find.text('Verify and load'), findsNothing);

    expect(find.byKey(const ValueKey('admin-load')), findsOneWidget);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  authenticatedAdminTests();
  Future<void> openDashboard(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AdminDashboardPage())),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Unauthenticated user cannot access admin data', (tester) async {
    await openDashboard(tester, const Size(1440, 900));

    expect(find.text('Administration'), findsOneWidget);

    expect(find.text('Return to REQVIORA'), findsOneWidget);

    expect(find.byKey(const ValueKey('admin-mfa-code')), findsNothing);

    expect(find.byKey(const ValueKey('admin-load')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    testWidgets('Admin access screen renders at ${size.width}x${size.height}', (
      tester,
    ) async {
      await openDashboard(tester, size);

      expect(find.text('Administration'), findsOneWidget);

      expect(find.text('Return to REQVIORA'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Protected dashboard can be safely disposed', (tester) async {
    await openDashboard(tester, const Size(1280, 800));

    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

void authenticatedAdminTests() {
  group('Authenticated Admin Dashboard', () {
    setUp(authSession.signOut);
    tearDown(authSession.signOut);

    final codeField = find.byKey(const ValueKey('admin-mfa-code'));

    final loadButton = find.byKey(const ValueKey('admin-load'));

    Future<void> open(
      WidgetTester tester,
      Future<http.Response> Function(http.Request) handler, {
      Size size = const Size(1440, 900),
    }) async {
      await tester.binding.setSurfaceSize(size);

      addTearDown(() => tester.binding.setSurfaceSize(null));

      authSession.signIn('widget-test-token');

      final api = ApiClient(MockClient(handler));

      addTearDown(api.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(home: AdminDashboardPage()),
        ),
      );

      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String code) async {
      await tester.ensureVisible(codeField);
      await tester.enterText(codeField, code);
      await tester.ensureVisible(loadButton);
      await tester.tap(loadButton);
      await tester.pumpAndSettle();
    }

    testWidgets('Authenticated dashboard exposes eight sections', (
      tester,
    ) async {
      await open(tester, (_) async {
        fail('Unexpected HTTP request');
      });

      for (final section in [
        'overview',
        'users',
        'roles',
        'projects',
        'audit',
        'login',
        'report',
        'health',
      ]) {
        expect(find.byKey(ValueKey('admin-section-$section')), findsOneWidget);
      }

      expect(codeField, findsOneWidget);
      expect(loadButton, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Invalid MFA code does not send a request', (tester) async {
      var calls = 0;

      await open(tester, (_) async {
        calls++;
        return http.Response('{}', 200);
      });

      await submit(tester, '123');

      expect(calls, 0);

      expect(
        find.text('Enter a valid six-digit authenticator code.'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Valid MFA submits overview and clears input', (tester) async {
      var calls = 0;

      await open(tester, (request) async {
        calls++;

        expect(request.method, 'POST');

        expect(request.url.path, '/api/admin/overview');

        expect(jsonDecode(request.body), {'code': '123456'});

        return http.Response(
          jsonEncode({
            'users': 42,
            'projects': 8,
            'drafts': 5,
            'auditEvents': 12,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await submit(tester, '123456');

      expect(calls, 1);
      expect(find.text('42'), findsOneWidget);

      expect(tester.widget<TextField>(codeField).controller!.text, isEmpty);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Forbidden admin request shows safe error', (tester) async {
      await open(tester, (_) async {
        return http.Response('{}', 403);
      });

      await submit(tester, '123456');

      expect(
        find.text('You are not authorized to access administration.'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('Server failure displays safe error', (tester) async {
      await open(tester, (_) async {
        return http.Response('private server details', 500);
      });

      await submit(tester, '123456');

      expect(find.text('Unable to load administration data.'), findsOneWidget);

      expect(find.text('private server details'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Switching sections clears previous MFA input', (tester) async {
      await open(tester, (_) async {
        fail('Unexpected HTTP request');
      });

      await tester.enterText(codeField, '123456');

      final users = find.byKey(const ValueKey('admin-section-users'));

      await tester.ensureVisible(users);
      await tester.tap(users);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(codeField).controller!.text, isEmpty);

      expect(find.text('Search'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sign out hides protected administration controls', (
      tester,
    ) async {
      await open(tester, (_) async {
        fail('Unexpected HTTP request');
      });

      authSession.signOut();

      await tester.pumpAndSettle();

      expect(codeField, findsNothing);
      expect(loadButton, findsNothing);

      expect(find.text('Return to REQVIORA'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    for (final size in [
      const Size(360, 640),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1440, 900),
    ]) {
      testWidgets('Authenticated layout ${size.width}x${size.height}', (
        tester,
      ) async {
        await open(tester, (_) async {
          fail('Unexpected HTTP request');
        }, size: size);

        await tester.ensureVisible(codeField);
        await tester.ensureVisible(loadButton);
        await tester.pumpAndSettle();

        expect(codeField, findsOneWidget);
        expect(loadButton, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
