import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/draft_restore_repository.dart';
import 'package:reqviora_frontend/features/workspace/presentation/draft_restore_panel.dart';

import '../draft_restore_repository_test.dart' as fixture;

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler, {
    bool enabled = true,
    bool canWrite = true,
    int version = 2,
    VoidCallback? onRestored,
  }) async {
    final api = ApiClient(MockClient(handler));

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraftRestorePanel(
            projectId: fixture.projectId,
            historicalVersion: version,
            repository: DraftRestoreRepository(api),
            integrationEnabled: enabled,
            canWrite: canWrite,
            onRestored: onRestored ?? () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  final button = find.byKey(const ValueKey('restore-draft-button'));

  Future<void> tapRestore(WidgetTester tester) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('restore-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('Disabled integration never calls backend', (tester) async {
    await open(
      tester,
      (_) async => throw StateError('Unexpected request'),
      enabled: false,
    );

    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

    expect(
      find.text('Draft restoration awaits backend integration.'),
      findsOneWidget,
    );
  });

  testWidgets('Write permission is required', (tester) async {
    await open(
      tester,
      (_) async => throw StateError('Unexpected request'),
      canWrite: false,
    );

    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
  });

  testWidgets('Cancel does not send restore request', (tester) async {
    var calls = 0;

    await open(tester, (request) async {
      calls++;
      expect(request.method, 'GET');
      return fixture.response(fixture.draft());
    });

    await tapRestore(tester);

    expect(find.text('Confirm draft restoration'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('restore-cancel')));

    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Confirmed restore returns new version', (tester) async {
    var writes = 0;
    var refreshed = false;

    await open(tester, (request) async {
      if (request.method == 'GET') {
        return fixture.response(fixture.draft());
      }

      writes++;

      expect(request.method, 'POST');

      expect(
        request.url.path,
        '/api/projects/${fixture.projectId}/drafts/versions/2/restore',
      );

      expect(jsonDecode(request.body), {
        'expectedConcurrencyToken': fixture.token,
      });

      return fixture.response(
        fixture.draft(version: 6, concurrencyToken: fixture.newToken),
      );
    }, onRestored: () => refreshed = true);

    await tapRestore(tester);
    expect(writes, 0);

    await confirm(tester);

    expect(writes, 1);
    expect(refreshed, isTrue);

    expect(
      find.text('Draft restored as v6. Reload and validate the workspace.'),
      findsOneWidget,
    );

    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
  });

  testWidgets('Approved draft cannot be restored', (tester) async {
    await open(tester, (request) async {
      expect(request.method, 'GET');

      return fixture.response(fixture.draft(approvedId: fixture.otherId));
    });

    await tapRestore(tester);

    expect(find.text('Approved drafts cannot be restored.'), findsOneWidget);

    expect(find.byKey(const ValueKey('restore-confirm')), findsNothing);
  });

  testWidgets('Concurrency conflict displays safe message', (tester) async {
    var writes = 0;

    await open(tester, (request) async {
      if (request.method == 'GET') {
        return fixture.response(fixture.draft());
      }

      writes++;

      return fixture.response({'title': 'Private server diagnostic'}, 409);
    });

    await tapRestore(tester);
    await confirm(tester);

    expect(writes, 1);

    expect(
      find.text('The draft changed or is locked. Reload before restoring.'),
      findsOneWidget,
    );

    expect(find.text('Private server diagnostic'), findsNothing);
  });

  testWidgets('Logout during confirmation blocks restore', (tester) async {
    var calls = 0;

    await open(tester, (request) async {
      calls++;
      expect(request.method, 'GET');

      return fixture.response(fixture.draft());
    });

    await tapRestore(tester);

    authSession.signOut();
    await tester.pumpAndSettle();

    await confirm(tester);

    expect(calls, 1);

    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);

    expect(tester.takeException(), isNull);
  });
}
