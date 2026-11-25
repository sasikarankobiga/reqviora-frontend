import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';

  http.Response reply(Object data, int status) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Local rules create draft suggestions and allow review', () async {
    var version = 2;
    var token = 'initial-token';

    Map<String, dynamic> draft = {
      'sections': {
        'sources': [
          {
            'id': 'source-1',
            'label': 'Requirements',
            'text':
                'Users must log in. The system should allow password reset.',
          },
        ],
        'candidates': <Map<String, dynamic>>[],
        'theme': {'mode': 'dark'},
      },
    };

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'Test Project',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'projectId': projectId,
          'version': version,
          'concurrencyToken': token,
          'draft': draft,
        }, 200);
      }

      if (request.method == 'PUT' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], token);

        draft = Map<String, dynamic>.from(body['draft'] as Map);
        version++;
        token = 'token-$version';

        return reply({
          'projectId': projectId,
          'version': version,
          'concurrencyToken': token,
          'draft': draft,
        }, 200);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final result = await repo.analyze(projectId, 2);
    expect(result['newSuggestions'], 2);
    expect(version, 3);

    final workspace = await repo.load(projectId);
    final candidates = workspace.items('candidates');

    expect(candidates.length, 2);
    expect(candidates.first['status'], 'suggested');
    expect(workspace.fields('theme')['mode'], 'dark');

    await repo.decideCandidate(
      projectId,
      candidates.first['id'].toString(),
      3,
      'accepted',
    );

    final reviewed = await repo.load(projectId);
    expect(reviewed.items('candidates').first['status'], 'accepted');
    expect(reviewed.items('candidates').last['status'], 'suggested');
    expect(reviewed.fields('theme')['mode'], 'dark');

    client.close();
  });

  test('Invalid candidate decision is rejected', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.decideCandidate(projectId, 'candidate-1', 0, 'invalid'),
      throwsArgumentError,
    );

    expect(requests, 0);
    client.close();
  });
}
