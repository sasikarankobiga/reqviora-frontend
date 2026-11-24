import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';
import 'package:reqviora_frontend/features/workspace/domain/local_preview_blueprint.dart';

void main() {
  test('Generated local preview persists and reloads from draft', () async {
    const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';

    var version = 1;
    var token = 'c5859ac2-7a39-4f5a-b937-5f1b2b591111';
    var putCount = 0;

    Map<String, dynamic> draft = {
      'sections': {
        'screens': [
          {'id': 'screen-home', 'name': 'Home'},
          {'id': 'screen-details', 'name': 'Details'},
        ],
        'components': [
          {
            'id': 'component-title',
            'screenId': 'screen-home',
            'type': 'text',
            'label': 'Welcome',
            'text': 'REQVIORA Preview',
          },
        ],
        'routes': [
          {
            'id': 'route-details',
            'fromScreenId': 'screen-home',
            'toScreenId': 'screen-details',
            'trigger': 'tap',
          },
        ],
        'theme': {'primaryColor': '#123456'},
        'identity': {'description': 'Keep this unchanged'},
      },
      'customMetadata': 'preserve-this',
    };

    http.Response reply(Object data, int status) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
    );

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' && path == '/api/projects/$projectId') {
        return reply({
          'id': projectId,
          'name': 'REQVIORA Test',
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
        putCount++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], token);

        draft = Map<String, dynamic>.from(body['draft'] as Map);
        version++;
        token = 'd5859ac2-7a39-4f5a-b937-5f1b2b59111$version';

        return reply({
          'id': projectId,
          'projectId': projectId,
          'version': version,
          'concurrencyToken': token,
          'draft': draft,
        }, 200);
      }

      return reply({'error': 'Unexpected API request: $path'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final before = await repo.load(projectId);
    final blueprint = buildLocalPreviewBlueprint(before);

    expect(blueprint['previewOnly'], true);

    final savedVersion = await repo.save(
      projectId,
      'blueprint',
      before.version,
      blueprint,
    );

    expect(savedVersion, 2);
    expect(putCount, 1);

    final after = await repo.load(projectId);
    final restored = after.fields('blueprint');

    expect(after.version, 2);
    expect(restored['previewOnly'], true);
    expect((restored['screens'] as List).length, 2);
    expect((restored['componentInstances'] as List).length, 1);
    expect((restored['routes'] as List).length, 1);

    expect(after.fields('theme')['primaryColor'], '#123456');
    expect(after.fields('identity')['description'], 'Keep this unchanged');
    expect(draft['customMetadata'], 'preserve-this');

    client.close();
  });
}
