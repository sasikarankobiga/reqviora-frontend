import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const initialToken = '22222222-2222-4222-8222-222222222222';
  const nextToken = '33333333-3333-4333-8333-333333333333';

  http.Response reply(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Saved Blueprint survives a fresh repository reload', () async {
    var version = 1;
    var token = initialToken;
    var writes = 0;

    var draft = <String, dynamic>{
      'sections': {
        'identity': {'name': 'REQVIORA', 'description': 'Preserve me'},
        'blueprint': <String, dynamic>{},
      },
    };

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' && path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'REQVIORA',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'id': projectId,
          'projectId': projectId,
          'version': version,
          'concurrencyToken': token,
          'draft': draft,
        }, 200);
      }

      if (request.method == 'PUT' &&
          path == '/api/projects/$projectId/drafts/current') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;

        expect(payload['expectedConcurrencyToken'], token);

        draft = Map<String, dynamic>.from(payload['draft'] as Map);
        version++;
        token = nextToken;
        writes++;

        return reply({
          'version': version,
          'concurrencyToken': token,
          'draft': draft,
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    addTearDown(client.close);

    final firstSession = WorkspaceRepository(ApiClient(client));
    final firstWorkspace = await firstSession.load(projectId);

    expect(firstWorkspace.version, 1);

    final blueprint = <String, dynamic>{
      'previewOnly': true,
      'origin': 'manual-builder',
      'screens': [
        {'screenId': 'home', 'name': 'Home'},
      ],
      'componentInstances': [
        {
          'componentInstanceId': 'welcome',
          'screenId': 'home',
          'type': 'text',
          'props': {'text': 'Recovered after refresh'},
        },
      ],
    };

    final savedVersion = await firstSession.save(
      projectId,
      'blueprint',
      firstWorkspace.version,
      blueprint,
    );

    expect(savedVersion, 2);
    expect(writes, 1);

    // Simulates reloading from the Backend with a new repository.
    final newSession = WorkspaceRepository(ApiClient(client));
    final recovered = await newSession.load(projectId);

    expect(recovered.version, 2);
    expect(recovered.fields('blueprint'), blueprint);
    expect(recovered.fields('identity')['description'], 'Preserve me');
    expect(writes, 1);
  });
}
