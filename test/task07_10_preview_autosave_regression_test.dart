import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets('Generated local draft autosaves when enabled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var saves = 0;
    var currentVersion = 1;
    var concurrencyToken = 'token-1';

    Map<String, dynamic> sections = {
      'screens': [
        {'id': 'home', 'name': 'Home'},
      ],
      'components': [
        {'id': 'welcome', 'screenId': 'home', 'type': 'text', 'text': 'Hello'},
      ],
      'routes': <Map<String, dynamic>>[],
      'blueprint': <String, dynamic>{},
      'interactions': <Map<String, dynamic>>[],
      'theme': {'mode': 'light'},
    };

    http.Response reply(Map<String, dynamic> data) => http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
    );

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/project-test') {
        return reply({
          'id': 'project-test',
          'name': 'REQVIORA',
          'primaryPlatform': 'web',
        });
      }

      if (request.method == 'GET' &&
          request.url.path.endsWith('/drafts/current')) {
        return reply({
          'id': 'draft-test',
          'projectId': 'project-test',
          'version': currentVersion,
          'concurrencyToken': concurrencyToken,
          'draft': {'sections': sections},
        });
      }

      if (request.method == 'PUT' &&
          request.url.path.endsWith('/drafts/current')) {
        saves++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final draft = body['draft'] as Map<String, dynamic>;
        final savedSections = draft['sections'] as Map<String, dynamic>;
        final blueprint =
            savedSections['visualEditorDraft'] as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], concurrencyToken);
        expect(blueprint['previewOnly'], true);
        expect(blueprint['screens'], isNotEmpty);
        expect(savedSections['theme'], {'mode': 'light'});

        currentVersion++;
        concurrencyToken = 'token-$currentVersion';

        sections = Map<String, dynamic>.from(savedSections);
        sections['visualEditorDraft'] = Map<String, dynamic>.from(blueprint);

        return reply({
          'version': currentVersion,
          'concurrencyToken': concurrencyToken,
          'draft': draft,
        });
      }

      return http.Response('Unexpected request', 500);
    });

    addTearDown(client.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(client)),
          builderMemberRoleProvider(
            'project-test',
          ).overrideWith((ref) async => ProjectMemberRole.owner),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuilderAuthoringPage(projectId: 'project-test', step: 7),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('step07-autosave-toggle'));

    await tester.ensureVisible(toggle);
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

    final refreshedToggle = tester.widget<FilterChip>(toggle);

    expect(refreshedToggle.selected, isTrue);

    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace Draft'));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(saves, 2);
    expect(currentVersion, 3);
    expect(concurrencyToken, 'token-3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Autosave flushes a pending Blueprint when leaving the editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    var saves = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'version': 1,
            'concurrencyToken': 'token-1',
            'draft': {
              'sections': {
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
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.method == 'PUT') {
        saves++;

        return http.Response(
          '{"version":2}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('{}', 500);
    });

    addTearDown(client.close);

    final api = ApiClient(client);

    final workspace = Workspace(
      projectId: 'leave-test',
      draftId: 'draft-leave',
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

    Widget app(Widget child) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        builderMemberRoleProvider(
          'project-test',
        ).overrideWith((ref) async => ProjectMemberRole.owner),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

    await tester.pumpWidget(
      app(
        SingleChildScrollView(child: V4BlueprintStudio(workspace: workspace)),
      ),
    );

    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('step07-autosave-toggle'));

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();

    final generate = find.text('Generate Local Preview');

    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));

    expect(saves, 0);

    await tester.pumpWidget(app(const SizedBox.shrink()));

    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(tester.takeException(), isNull);
  });
}
