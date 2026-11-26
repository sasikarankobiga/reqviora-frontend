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

  test('Blueprint validation uses current Backend endpoint', () async {
    var validationCalls = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'projectId': projectId,
          'version': 3,
          'concurrencyToken': token,
          'draft': {
            'identity': {'name': 'REQVIORA Demo'},
          },
        }, 200);
      }

      if (request.method == 'POST' &&
          request.url.path == '/api/projects/$projectId/blueprints/validate') {
        validationCalls++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], token);

        return reply({
          'id': 'validation-id',
          'passed': false,
          'findings': [
            {
              'code': 'MISSING_BLUEPRINT',
              'path': '/',
              'message': 'A valid blueprint is required.',
            },
          ],
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final result = await repo.validate(projectId);

    expect(result['passed'], false);
    expect((result['findings'] as List).length, 1);
    expect(validationCalls, 1);

    client.close();
  });

  test('Local Blueprint generation saves through Backend Draft API', () async {
    var putCount = 0;

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'REQVIORA Demo',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'projectId': projectId,
          'version': 1,
          'concurrencyToken': token,
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
                  'text': 'REQVIORA Welcome',
                },
              ],
              'routes': <Map<String, dynamic>>[],
              'theme': {'primaryColor': '#123456'},
              'identity': {'description': 'Keep this'},
            },
          },
        }, 200);
      }

      if (request.method == 'PUT' &&
          path == '/api/projects/$projectId/drafts/current') {
        putCount++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);

        final draft = body['draft'] as Map<String, dynamic>;
        final sections = draft['sections'] as Map<String, dynamic>;
        final blueprint = sections['blueprint'] as Map<String, dynamic>;

        expect(blueprint['previewOnly'], true);
        expect(blueprint['origin'], 'manual-builder');
        expect(blueprint['screens'], isNotEmpty);
        expect(blueprint['componentInstances'], isNotEmpty);
        expect(sections['theme'], {'primaryColor': '#123456'});
        expect(sections['identity'], {'description': 'Keep this'});

        return reply({
          'version': 2,
          'concurrencyToken': 'next-token',
          'draft': draft,
        }, 200);
      }

      return reply({'error': 'Unexpected request: ${request.method} $path'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final result = await repo.compile(projectId, 1);

    expect(result['draftVersion'], 2);
    expect(result['generationMode'], 'local-template');
    expect(result['serverSaved'], true);
    expect(result['approved'], false);
    expect(putCount, 1);

    client.close();
  });

  test('Local compile rejects stale versions without saving', () async {
    var puts = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'REQVIORA',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          request.url.path.endsWith('/drafts/current')) {
        return reply({
          'version': 2,
          'concurrencyToken': token,
          'draft': <String, dynamic>{},
        }, 200);
      }

      if (request.method == 'PUT') puts++;
      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.compile(projectId, 1),
      throwsA(isA<StateError>()),
    );

    expect(puts, 0);
    client.close();
  });

  test('Draft ZIP export is explicitly unsupported', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.exportDraft(projectId),
      throwsA(isA<UnsupportedError>()),
    );

    expect(requests, 0);
    client.close();
  });
}
