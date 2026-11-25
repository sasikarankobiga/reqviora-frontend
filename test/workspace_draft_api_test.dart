import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';
  const token = 'c5859ac2-7a39-4f5a-b937-5f1b2b591111';

  http.Response reply(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> project() => {
    'id': projectId,
    'name': 'REQVIORA Demo',
    'primaryPlatform': 'web',
  };

  test('Load new project without an existing draft', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId') {
        return reply(project(), 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({'title': 'Not Found'}, 404);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final workspace = await repo.load(projectId);

    expect(workspace.projectId, projectId);
    expect(workspace.version, 0);
    expect(workspace.projectName, 'REQVIORA Demo');
    expect(workspace.designTargets, contains('web'));
    expect(workspace.items('sources'), isEmpty);

    client.close();
  });

  test('Load existing draft with nested sections', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId') {
        return reply(project(), 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'id': 'draft-id',
          'projectId': projectId,
          'version': 3,
          'concurrencyToken': token,
          'draft': {
            'sections': {
              'sources': [
                {'id': 'source-1', 'name': 'Requirements'},
              ],
              'theme': {'mode': 'dark'},
            },
          },
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final workspace = await repo.load(projectId);

    expect(workspace.version, 3);
    expect(workspace.draftId, 'draft-id');
    expect(workspace.items('sources').length, 1);
    expect(workspace.fields('theme')['mode'], 'dark');

    client.close();
  });

  test('Save preserves unrelated draft data and concurrency token', () async {
    var putCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'projectId': projectId,
          'version': 4,
          'concurrencyToken': token,
          'draft': {
            'identity': {'name': 'Original Project'},
            'sections': {
              'theme': {'mode': 'light'},
              'features': [
                {'id': 'feature-1', 'name': 'Login'},
              ],
            },
            'customMetadata': {'keep': true},
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

        expect((draft['identity'] as Map)['name'], 'Original Project');
        expect((draft['customMetadata'] as Map)['keep'], true);
        expect((sections['features'] as List).length, 1);
        expect((sections['theme'] as Map)['mode'], 'dark');

        return reply({
          'projectId': projectId,
          'version': 5,
          'concurrencyToken': 'next-token',
          'draft': draft,
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final newVersion = await repo.save(projectId, 'theme', 4, {'mode': 'dark'});

    expect(newVersion, 5);
    expect(putCount, 1);

    client.close();
  });

  test('Reject stale workspace version before sending PUT', () async {
    var putCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'projectId': projectId,
          'version': 8,
          'concurrencyToken': token,
          'draft': <String, dynamic>{},
        }, 200);
      }

      if (request.method == 'PUT') {
        putCount++;
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.save(projectId, 'theme', 7, {'mode': 'dark'}),
      throwsA(isA<StateError>()),
    );

    expect(putCount, 0);

    client.close();
  });

  test('First workspace save sends a null concurrency token', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({'title': 'Not Found'}, 404);
      }

      if (request.method == 'PUT' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], isNull);
        expect((body['draft'] as Map)['theme'], {'mode': 'dark'});

        return reply({
          'projectId': projectId,
          'version': 1,
          'concurrencyToken': token,
          'draft': body['draft'],
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final version = await repo.save(projectId, 'theme', 0, {'mode': 'dark'});

    expect(version, 1);

    client.close();
  });
}
