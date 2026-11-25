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

  test('Automatic compile is explicitly unsupported', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.compile(projectId, 1),
      throwsA(isA<UnsupportedError>()),
    );

    expect(requests, 0);
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
