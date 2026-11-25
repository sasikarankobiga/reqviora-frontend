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

  test('Text source appends without deleting existing sections', () async {
    var putCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'REQVIORA Demo',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'projectId': projectId,
          'version': 2,
          'concurrencyToken': token,
          'draft': {
            'identity': {'name': 'REQVIORA Demo'},
            'sections': {
              'sources': [
                {
                  'id': 'old-source',
                  'label': 'Existing source',
                  'text': 'Original requirement',
                },
              ],
              'features': [
                {'id': 'feature-1', 'name': 'Login'},
              ],
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
        final sources = sections['sources'] as List;

        expect(sources.length, 2);
        expect((sources.first as Map)['id'], 'old-source');
        expect((sources.last as Map)['label'], 'New requirements');
        expect(
          (sources.last as Map)['text'],
          'Users should be able to log in.',
        );

        expect((sections['features'] as List).length, 1);
        expect((draft['identity'] as Map)['name'], 'REQVIORA Demo');

        return reply({
          'projectId': projectId,
          'version': 3,
          'concurrencyToken': 'next-token',
          'draft': draft,
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await repo.addText(
      projectId,
      2,
      'Users should be able to log in.',
      'New requirements',
    );

    expect(putCount, 1);
    client.close();
  });

  test('Empty text is rejected', () async {
    var calls = 0;

    final client = MockClient((request) async {
      calls++;
      return reply({'error': 'Unexpected'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.addText(projectId, 0, '   ', 'Empty'),
      throwsArgumentError,
    );

    expect(calls, 0);
    client.close();
  });
}
