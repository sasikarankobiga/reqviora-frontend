import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/http_projects_repository.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';

void main() {
  test('nested draft identity loads without losing sections', () {
    final draft = ProjectDraft.fromJson({
      'projectId': 'project-1',
      'version': 2,
      'concurrencyToken': 'token-2',
      'project': {'name': 'Coffee Shop', 'primaryPlatform': 'web'},
      'draft': {
        'sections': {
          'identity': {'name': 'Saved Project', 'tagline': 'Fresh Coffee'},
          'theme': {'mode': 'dark'},
        },
      },
    });

    expect(draft.name, 'Saved Project');
    expect(draft.field('tagline'), 'Fresh Coffee');
    expect(draft.version, 2);
    expect(draft.concurrencyToken, 'token-2');
    expect((draft.rawDraft['sections'] as Map)['theme'], {'mode': 'dark'});
  });

  test('legacy draft version retains token and raw draft', () {
    final draft = ProjectDraft.fromJson({
      'projectId': 'legacy-project',
      'draftVersion': 3,
      'concurrencyToken': 'legacy-token',
      'project': {
        'name': 'Legacy',
        'designTargets': ['web'],
        'identity': {'tagline': 'Legacy tagline'},
      },
      'draft': {
        'features': [
          {'id': 'feature-1'},
        ],
      },
    });

    expect(draft.version, 3);
    expect(draft.concurrencyToken, 'legacy-token');
    expect(draft.rawDraft['features'], isNotNull);
    expect(draft.field('tagline'), 'Legacy tagline');
  });

  test('saving nested identity preserves other sections', () async {
    const id = 'project-1';
    var puts = 0;

    final client = MockClient((request) async {
      final path = request.url.path;

      http.Response jsonResponse(Object data, int status) => http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json'},
      );

      if (request.method == 'GET' && path == '/api/projects/$id') {
        return jsonResponse({
          'id': id,
          'name': 'Coffee Shop',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$id/drafts/current') {
        return jsonResponse({
          'projectId': id,
          'version': 2,
          'concurrencyToken': 'token-2',
          'draft': {
            'sections': {
              'identity': {'name': 'Before'},
              'theme': {'mode': 'dark'},
            },
          },
        }, 200);
      }

      if (request.method == 'PUT' &&
          path == '/api/projects/$id/drafts/current') {
        puts++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], 'token-2');

        final savedDraft = body['draft'] as Map<String, dynamic>;
        final sections = savedDraft['sections'] as Map<String, dynamic>;
        final identity = sections['identity'] as Map<String, dynamic>;

        expect(identity['name'], 'After');
        expect(sections['theme'], {'mode': 'dark'});
        expect(savedDraft.containsKey('identity'), isFalse);

        return jsonResponse({
          'projectId': id,
          'version': 3,
          'concurrencyToken': 'token-3',
          'draft': savedDraft,
        }, 200);
      }

      return jsonResponse({'error': 'Unexpected request'}, 500);
    });

    final repo = HttpProjectsRepository(ApiClient(client));

    try {
      final saved = await repo.saveIdentity(id, {
        'expectedVersion': 2,
        'name': 'After',
      });

      expect(puts, 1);
      expect(saved.name, 'After');
      expect(saved.version, 3);
      expect(saved.concurrencyToken, 'token-3');
      expect((saved.rawDraft['sections'] as Map)['theme'], {'mode': 'dark'});
    } finally {
      client.close();
    }
  });
}
