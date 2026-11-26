import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/application/auth_providers.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/workspace/presentation/revision_history_panel.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const revisionId = '22222222-2222-4222-8222-222222222222';
const draftId = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> historicalBlueprint() => {
  'projectId': projectId,
  'screens': [],
  'components': [],
  'navigation': [],
  'actions': [],
};

Map<String, dynamic> approvedRevision() => {
  'revisionId': revisionId,
  'draftVersion': 3,
  'approvedAt': '2026-11-25T12:00:00Z',
  'blueprint': historicalBlueprint(),
};

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      MockClient((request) {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-session');

        return handler(request);
      }),
    );

    addTearDown(api.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository(api)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevisionHistoryPanel(projectId: projectId),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> loadApproved(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('load-approved-history')));

    await tester.pumpAndSettle();
  }

  testWidgets('Approved revision history displays server records', (
    tester,
  ) async {
    await open(tester, (request) async {
      expect(request.url.path, '/api/projects/$projectId/blueprints/approved');

      return response([approvedRevision()]);
    });

    await loadApproved(tester);

    expect(find.text('Approved v3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('preview-history-$revisionId')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('Historical preview loads the exact approved revision', (
    tester,
  ) async {
    var calls = 0;

    await open(tester, (request) async {
      calls++;

      if (calls == 1) {
        expect(
          request.url.path,
          '/api/projects/$projectId/blueprints/approved',
        );

        return response([approvedRevision()]);
      }

      expect(
        request.url.path,
        '/api/projects/$projectId/blueprints/approved/$revisionId',
      );

      return response(approvedRevision());
    });

    await loadApproved(tester);

    await tester.tap(find.byKey(const ValueKey('preview-history-$revisionId')));

    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(SafePreview), findsOneWidget);
    expect(
      find.text('Read-only simulation. Changes are not saved.'),
      findsOneWidget,
    );

    final preview = tester.widget<SafePreview>(find.byType(SafePreview));

    expect(preview.blueprint['projectId'], projectId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Draft without Blueprint disables preview', (tester) async {
    await open(tester, (request) async {
      expect(request.url.path, '/api/projects/$projectId/drafts/versions');

      return response([
        {
          'draftVersionId': draftId,
          'version': 2,
          'savedAt': '2026-11-24T12:00:00Z',
          'blueprint': null,
        },
      ]);
    });

    await tester.tap(find.byKey(const ValueKey('load-draft-history')));

    await tester.pumpAndSettle();

    expect(find.text('Draft v2'), findsOneWidget);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('preview-history-$draftId')),
    );

    expect(button.onPressed, isNull);
    expect(find.byType(SafePreview), findsNothing);
  });

  testWidgets('Permission rejection displays safe error', (tester) async {
    await open(tester, (request) async {
      return response({'title': 'Private authorization diagnostic'}, 403);
    });

    await loadApproved(tester);

    expect(
      find.text('You do not have permission to view this history.'),
      findsOneWidget,
    );

    expect(find.text('Private authorization diagnostic'), findsNothing);

    expect(find.byType(SafePreview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logout clears historical records', (tester) async {
    await open(tester, (request) async {
      return response([approvedRevision()]);
    });

    await loadApproved(tester);

    expect(find.text('Approved v3'), findsOneWidget);

    authSession.signOut();

    await tester.pumpAndSettle();

    expect(find.text('Approved v3'), findsNothing);
    expect(find.byType(SafePreview), findsNothing);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('load-approved-history')),
    );

    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
