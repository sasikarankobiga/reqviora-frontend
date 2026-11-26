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
  testWidgets('Generated local draft autosaves when enabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var saves = 0;

    http.Response reply(Map<String, dynamic> data) => http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
    );

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/drafts/current')) {
        return reply({
          'version': 1,
          'concurrencyToken': 'token-1',
          'draft': {
            'sections': {
              'blueprint': <String, dynamic>{},
              'theme': {'mode': 'light'},
            },
          },
        });
      }
      if (request.method == 'PUT' &&
          request.url.path.endsWith('/drafts/current')) {
        saves++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final draft = body['draft'] as Map<String, dynamic>;
        final sections = draft['sections'] as Map<String, dynamic>;
        final blueprint = sections['blueprint'] as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], 'token-1');
        expect(blueprint['previewOnly'], true);
        expect(blueprint['screens'], isNotEmpty);
        expect(sections['theme'], {'mode': 'light'});
        return reply({'version': 2, 'draft': draft});
      }

      return http.Response('Unexpected request', 500);
    });
    addTearDown(client.close);

    final workspace = Workspace(
      projectId: 'project-test',
      draftId: 'draft-test',
      version: 1,
      projectName: 'REQVIORA',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'home', 'name': 'Home'},
        ],
        'components': [
          {
            'id': 'welcome',
            'screenId': 'home',
            'type': 'text',
            'text': 'Hello',
          },
        ],
        'routes': <Map<String, dynamic>>[],
        'blueprint': <String, dynamic>{},
        'interactions': <Map<String, dynamic>>[],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(ApiClient(client))],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintStudio(workspace: workspace),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('step07-autosave-toggle'));
    await tester.tap(toggle);
    await tester.pump();

    final generate = find.text('Generate Local Preview');
    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();

    expect(saves, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(saves, 0);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(find.textContaining('Blueprint draft saved - v2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
