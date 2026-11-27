import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/app/widgets.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets('Error view provides a working Retry action', (tester) async {
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineError('Network unavailable', onRetry: () => retries++),
        ),
      ),
    );

    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('Error view does not show Retry without callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InlineError('Access denied'))),
    );

    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('Error UI fits a narrow mobile viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InlineError('Unable to connect', onRetry: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Unable to connect'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Builder recovers from API error after Retry', (tester) async {
    const projectId = 'project-qa';
    var projectLoads = 0;
    var allowSuccess = false;

    http.Response jsonReply(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId') {
        projectLoads++;

        if (!allowSuccess) {
          return jsonReply({'title': 'Service unavailable'}, 503);
        }

        return jsonReply({
          'id': projectId,
          'name': 'QA Test Project',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return jsonReply({
          'projectId': projectId,
          'version': 1,
          'concurrencyToken': 'test-token',
          'draft': {'sections': <String, dynamic>{}},
        }, 200);
      }

      return jsonReply({'title': 'Unexpected request'}, 500);
    });

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(client.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(client)),
          builderMemberRoleProvider(
            projectId,
          ).overrideWith((ref) async => ProjectMemberRole.owner),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuilderAuthoringPage(projectId: projectId, step: 8),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Service unavailable'), findsWidgets);
    expect(find.text('Retry'), findsOneWidget);

    allowSuccess = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(projectLoads, greaterThanOrEqualTo(2));
    expect(find.text('Review, Approval & Export'), findsOneWidget);
    expect(find.text('Run Backend Validation'), findsOneWidget);
  });
}
