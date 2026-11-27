import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/prebuilder/presentation/clarification_dialog.dart';
import 'package:reqviora_frontend/features/workspace/application/workspace_providers.dart';
import 'package:reqviora_frontend/features/workspace/data/ai_intelligence_repository.dart';

const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';

const token = 'd5859ac2-7a39-4f5a-b937-5f1b2b593333';

Future<void> openDialog(
  WidgetTester tester,
  ApiClient api, {
  bool readOnly = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiIntelligenceRepositoryProvider.overrideWithValue(
          AiIntelligenceRepository(api),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ClarificationDialog(
            projectId: projectId,
            draftVersion: 1,
            requirementId: 'REQ-001',
            readOnly: readOnly,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    authSession.signOut();
    authSession.signIn('test-access');
  });

  tearDown(authSession.signOut);

  testWidgets('Read-only dialog does not allow clarification writes', (
    tester,
  ) async {
    var calls = 0;

    final api = ApiClient(
      MockClient((request) async {
        calls++;

        expect(request.method, 'GET');

        return http.Response(
          jsonEncode([
            {
              'id': 'question-1',
              'requirementId': 'REQ-001',
              'question': 'Which users need access?',
              'answer': null,
              'revision': 1,
            },
          ]),
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    await openDialog(tester, api, readOnly: true);

    expect(find.byKey(const ValueKey('clarification-question')), findsNothing);

    expect(find.text('Save clarification'), findsNothing);

    await tester.tap(find.text('Load clarifications'));
    await tester.pumpAndSettle();

    expect(find.text('Which users need access?'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Review sync displays actual server status', (tester) async {
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/requirements/candidates')) {
          return http.Response(
            '[{"id":"REQ-001","status":"confirmed","revision":2}]',
            200,
          );
        }

        expect(request.url.path, '/api/projects/$projectId/blueprints/current');

        return http.Response(
          jsonEncode({
            'blueprint': {'revision': 2, 'requirements': <Object>[]},
          }),
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    await openDialog(tester, api, readOnly: true);

    await tester.tap(find.text('Check Blueprint sync'));
    await tester.pumpAndSettle();

    expect(find.text('Server reports synchronization issues.'), findsOneWidget);

    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Stale draft version prevents clarification POST', (
    tester,
  ) async {
    var writes = 0;
    var reads = 0;

    final api = ApiClient(
      MockClient((request) async {
        if (request.method == 'POST') {
          writes++;
          return http.Response('{}', 500);
        }

        reads++;

        expect(request.url.path, '/api/projects/$projectId/drafts/current');

        return http.Response(
          jsonEncode({
            'version': 2,
            'concurrencyToken': token,
            'approvedRevisionId': null,
          }),
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    await openDialog(tester, api);

    await tester.enterText(
      find.byKey(const ValueKey('clarification-question')),
      'Which users need access?',
    );

    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save clarification'));
    await tester.tap(find.text('Save clarification'));

    await tester.pumpAndSettle();

    expect(reads, 1);
    expect(writes, 0);

    expect(
      find.text('The draft changed or is approved. Close and reload.'),
      findsOneWidget,
    );

    expect(find.text('Save clarification'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Session change disables access to clarification data', (
    tester,
  ) async {
    var calls = 0;

    final api = ApiClient(
      MockClient((request) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );

    addTearDown(api.dispose);

    await openDialog(tester, api);

    authSession.signOut();

    await tester.pumpAndSettle();

    expect(
      find.text('Your session changed. Close this dialog and sign in again.'),
      findsOneWidget,
    );

    expect(find.text('Save clarification'), findsNothing);

    final loadButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Load clarifications'),
    );

    expect(loadButton.onPressed, isNull);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
