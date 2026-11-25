import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  const projectId = 'project-1';
  const token = 'revision-token-1';

  Map<String, dynamic> blueprint(String text) => {
    'screens': [
      {'screenId': 'home', 'name': 'Home'},
    ],
    'componentInstances': [
      {
        'componentInstanceId': 'title-1',
        'screenId': 'home',
        'type': 'text',
        'props': {'text': text},
      },
    ],
  };

  Workspace workspace() => Workspace(
    projectId: projectId,
    draftId: 'draft-1',
    version: 1,
    projectName: 'REQVIORA Test',
    designTargets: const ['web'],
    sections: {
      'interactions': <Map<String, dynamic>>[],
      'blueprint': blueprint('Welcome'),
    },
  );

  http.Response response(Object data, int status) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<void> openEditor(WidgetTester tester, MockClient client) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(ApiClient(client))],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintStudio(workspace: workspace()),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('select-component-title-1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('step07-edit-text-title-1')),
      'Updated REQVIORA',
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Save sends updated Blueprint and preserves draft data', (
    tester,
  ) async {
    var putCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return response({
          'projectId': projectId,
          'version': 1,
          'concurrencyToken': token,
          'draft': {
            'sections': {
              'blueprint': blueprint('Welcome'),
              'theme': {'mode': 'dark'},
            },
          },
        }, 200);
      }

      if (request.method == 'PUT' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        putCount++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);

        final draft = body['draft'] as Map<String, dynamic>;
        final sections = draft['sections'] as Map<String, dynamic>;
        final saved = sections['blueprint'] as Map<String, dynamic>;
        final components = saved['componentInstances'] as List;
        final component = components.first as Map<String, dynamic>;
        final props = component['props'] as Map<String, dynamic>;

        expect(props['text'], 'Updated REQVIORA');
        expect(sections['theme'], {'mode': 'dark'});

        return response({
          'version': 2,
          'concurrencyToken': 'revision-token-2',
          'draft': draft,
        }, 200);
      }

      return response({'error': 'Unexpected request'}, 500);
    });

    await openEditor(tester, client);

    final save = find.byKey(const ValueKey('step07-save-draft-button'));
    expect(save, findsOneWidget);

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(putCount, 1);
    expect(find.textContaining('Blueprint draft saved - v2'), findsOneWidget);
    expect(save, findsNothing);

    client.close();
  });

  testWidgets('Stale draft version retains unsaved changes', (tester) async {
    var putCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return response({
          'projectId': projectId,
          'version': 2,
          'concurrencyToken': 'new-token',
          'draft': {
            'sections': {'blueprint': blueprint("Another user's changes")},
          },
        }, 200);
      }

      if (request.method == 'PUT') {
        putCount++;
      }

      return response({'error': 'Unexpected request'}, 500);
    });

    await openEditor(tester, client);

    final save = find.byKey(const ValueKey('step07-save-draft-button'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(putCount, 0);
    expect(
      find.textContaining('Blueprint draft was not saved'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);
    expect(find.text('Updated REQVIORA'), findsWidgets);
    expect(save, findsOneWidget);

    client.close();
  });
}
