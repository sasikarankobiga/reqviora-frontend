import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const token = '22222222-2222-4222-8222-222222222222';

  Map<String, dynamic> validBlueprint() => {
    'schemaVersion': '1.0.0',
    'blueprintId': 'BP-001',
    'projectId': projectId,
    'revision': 1,
    'lifecycle': 'draft',
    'targetPlatforms': ['web'],
    'requirements': <Map<String, dynamic>>[],
    'features': <Map<String, dynamic>>[],
    'screens': <Map<String, dynamic>>[],
    'components': <Map<String, dynamic>>[],
    'actions': <Map<String, dynamic>>[],
    'navigation': <Map<String, dynamic>>[],
  };

  http.Response reply(Object value, int status) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Blueprint v1 uses the official Backend endpoint', () async {
    var writes = 0;

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'version': 3,
          'concurrencyToken': token,
          'draft': {
            'sections': {
              'identity': {'name': 'Keep this'},
              'theme': {'mode': 'dark'},
            },
          },
        }, 200);
      }

      if (request.method == 'PUT' &&
          path == '/api/projects/$projectId/blueprints/current') {
        writes++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);
        expect(body['blueprint'], validBlueprint());

        final draft = body['draft'] as Map;
        final sections = draft['sections'] as Map;
        expect(sections['identity'], {'name': 'Keep this'});
        expect(sections['theme'], {'mode': 'dark'});

        return reply({
          'version': 4,
          'concurrencyToken': 'next-token',
          'draft': draft,
        }, 200);
      }

      return reply({'title': 'Unexpected request'}, 500);
    });

    addTearDown(client.close);
    final repository = WorkspaceRepository(ApiClient(client));

    final version = await repository.saveBackendBlueprint(
      projectId,
      3,
      validBlueprint(),
    );

    expect(version, 4);
    expect(writes, 1);
  });

  test('Stale version prevents official Blueprint write', () async {
    var writes = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return reply({
          'version': 5,
          'concurrencyToken': token,
          'draft': <String, dynamic>{},
        }, 200);
      }

      if (request.method == 'PUT') writes++;
      return reply({'title': 'Unexpected request'}, 500);
    });

    addTearDown(client.close);
    final repository = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repository.saveBackendBlueprint(projectId, 4, validBlueprint()),
      throwsA(isA<StateError>()),
    );

    expect(writes, 0);
  });

  test('Local preview cannot masquerade as Backend Blueprint v1', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return reply({'title': 'Unexpected request'}, 500);
    });

    addTearDown(client.close);
    final repository = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repository.saveBackendBlueprint(projectId, 1, {
        'previewOnly': true,
        'screens': <Map<String, dynamic>>[],
        'componentInstances': <Map<String, dynamic>>[],
      }),
      throwsA(isA<ArgumentError>()),
    );

    expect(requests, 0);
  });
}
