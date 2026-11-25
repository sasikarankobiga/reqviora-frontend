import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  const projectId = 'step08-test-project';
  const token = 'step08-concurrency-token';

  http.Response reply(Object body, int status) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<void> openStep08(
    WidgetTester tester, {
    required Map<String, dynamic> validation,
    required void Function() onValidate,
    void Function()? onApprove,
  }) async {
    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'REQVIORA Step 08 Test',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'id': 'draft-1',
          'projectId': projectId,
          'version': 1,
          'concurrencyToken': token,
          'draft': {
            'sections': {
              'identity': {'projectName': 'Test'},
              'blueprint': <String, dynamic>{},
            },
          },
        }, 200);
      }

      if (request.method == 'POST' &&
          path == '/api/projects/$projectId/blueprints/validate') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);
        onValidate();
        return reply(validation, 200);
      }

      if (request.method == 'POST' &&
          path == '/api/projects/$projectId/approvals') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);
        expect(body['validationRunId'], 'validation-approval');
        onApprove?.call();
        return reply({
          'revisionId': 'approved-revision-123',
        }, 201);
      }

      return reply({'error': 'Unexpected request: $path'}, 500);
    });

    addTearDown(client.close);

    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(client)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuilderAuthoringPage(
                projectId: projectId,
                step: 8,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> validate(WidgetTester tester) async {
    final button = find.text('Run Backend Validation');
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Zero blockers show validation readiness, not approval', (
    tester,
  ) async {
    var requests = 0;

    await openStep08(
      tester,
      validation: {
        'draftVersion': 1,
        'blockers': 0,
        'advisories': 0,
        'findings': [],
      },
      onValidate: () => requests++,
    );

    await validate(tester);

    expect(requests, 1);
    expect(
      find.byKey(const ValueKey('step08-validation-ready')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Approval is still required'),
      findsOneWidget,
    );
  });

  testWidgets('Blockers prevent a ready validation message', (
    tester,
  ) async {
    await openStep08(
      tester,
      validation: {
        'draftVersion': 1,
        'blockers': 2,
        'advisories': 1,
        'findings': [
          {
            'ruleId': 'MISSING_SCREEN',
            'severity': 'blocker',
            'message': 'Screen mapping is missing',
          },
        ],
      },
      onValidate: () {},
    );

    await validate(tester);

    expect(
      find.byKey(const ValueKey('step08-validation-blocked')),
      findsOneWidget,
    );
    expect(find.text('Screen mapping is missing'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('step08-validation-ready')),
      findsNothing,
    );
  });

  testWidgets('Missing blocker count is not considered ready', (
    tester,
  ) async {
    await openStep08(
      tester,
      validation: {
        'draftVersion': 1,
        'advisories': 0,
        'findings': [],
      },
      onValidate: () {},
    );

    await validate(tester);

    expect(
      find.byKey(const ValueKey('step08-validation-incomplete')),
      findsOneWidget,
    );
  });

  testWidgets('Real backend passed response shows readiness', (
    tester,
  ) async {
    var requests = 0;

    await openStep08(
      tester,
      validation: {
        'id': 'validation-1',
        'draftVersionId': 'draft-version-1',
        'passed': true,
        'validatedAt': '2026-11-25T05:30:00Z',
        'findings': [],
      },
      onValidate: () => requests++,
    );

    await validate(tester);

    expect(requests, 1);
    expect(find.text('Backend validation passed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('step08-validation-ready')),
      findsOneWidget,
    );
  });

  testWidgets('Real backend failed response blocks readiness', (
    tester,
  ) async {
    await openStep08(
      tester,
      validation: {
        'id': 'validation-2',
        'draftVersionId': 'draft-version-1',
        'passed': false,
        'findings': [
          {
            'ordinal': 1,
            'code': 'SCREEN_MISSING',
            'path': '/screens',
            'message': 'Required screen is missing',
          },
        ],
      },
      onValidate: () {},
    );

    await validate(tester);

    expect(find.text('Backend validation failed'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('step08-validation-blocked')),
      findsOneWidget,
    );
    expect(find.text('Required screen is missing'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('step08-validation-ready')),
      findsNothing,
    );
  });
  testWidgets('Unsupported ZIP export remains disabled', (
    tester,
  ) async {
    await openStep08(
      tester,
      validation: {
        'blockers': 0,
        'advisories': 0,
        'findings': [],
      },
      onValidate: () {},
    );

    final exportButton = find.byKey(
      const ValueKey('step08-export-disabled'),
    );

    expect(exportButton, findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(exportButton).onPressed,
      isNull,
    );
    expect(
      find.byKey(const ValueKey('step08-export-unavailable')),
      findsOneWidget,
    );
  });
  testWidgets('Approval confirmation cancelled sends no approval request', (
    tester,
  ) async {
    var approvals = 0;

    await openStep08(
      tester,
      validation: {
        'id': 'validation-approval',
        'passed': true,
        'findings': [],
      },
      onValidate: () {},
      onApprove: () => approvals++,
    );

    await validate(tester);

    final approve = find.byKey(
      const ValueKey('step08-approve-button'),
    );

    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(find.text('Approve Blueprint revision?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(approvals, 0);
    expect(
      find.byKey(const ValueKey('step08-approved-revision')),
      findsNothing,
    );
  });

  testWidgets('Confirmed approval displays returned revision ID', (
    tester,
  ) async {
    var approvals = 0;

    await openStep08(
      tester,
      validation: {
        'id': 'validation-approval',
        'passed': true,
        'findings': [],
      },
      onValidate: () {},
      onApprove: () => approvals++,
    );

    await validate(tester);

    final approve = find.byKey(
      const ValueKey('step08-approve-button'),
    );

    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(approvals, 0);

    await tester.tap(find.text('Confirm Approval'));
    await tester.pumpAndSettle();

    expect(approvals, 1);
    expect(
      find.text('Approved revision: approved-revision-123'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(approve).onPressed,
      isNull,
    );
  });

  testWidgets('Failed backend validation disables approval', (
    tester,
  ) async {
    var approvals = 0;

    await openStep08(
      tester,
      validation: {
        'id': 'validation-approval',
        'passed': false,
        'findings': [],
      },
      onValidate: () {},
      onApprove: () => approvals++,
    );

    await validate(tester);

    final approve = find.byKey(
      const ValueKey('step08-approve-button'),
    );

    expect(
      tester.widget<FilledButton>(approve).onPressed,
      isNull,
    );
    expect(approvals, 0);
  });

}