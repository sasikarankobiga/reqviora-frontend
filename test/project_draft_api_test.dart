import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/http_projects_repository.dart';

void main() {
  const id = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';
  const token = 'c5859ac2-7a39-4f5a-b937-5f1b2b591111';

  Map<String, dynamic> project() => {
    'id': id,
    'name': 'Coffee Shop',
    'description': 'Demo project',
    'industry': 'Food & Beverage',
    'primaryPlatform': 'web',
  };

  http.Response jsonResponse(Object data, int status) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('New project can create its first draft', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');

      if (request.method == 'GET' && request.url.path == '/api/projects/$id') {
        return jsonResponse(project(), 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$id/drafts/current') {
        return jsonResponse({'title': 'Not Found'}, 404);
      }

      if (request.method == 'PUT' &&
          request.url.path == '/api/projects/$id/drafts/current') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], isNull);
        final draft = body['draft'] as Map<String, dynamic>;
        final identity = draft['identity'] as Map<String, dynamic>;
        expect(identity['name'], 'Coffee Shop Updated');
        expect(identity.containsKey('expectedVersion'), isFalse);

        return jsonResponse({
          'projectId': id,
          'version': 1,
          'concurrencyToken': token,
          'draft': draft,
        }, 200);
      }

      return jsonResponse({'title': 'Unexpected request'}, 404);
    });

    final repo = HttpProjectsRepository(ApiClient(client));

    final initial = await repo.draft(id);
    expect(initial.version, 0);
    expect(initial.concurrencyToken, isNull);
    expect(initial.name, 'Coffee Shop');

    final saved = await repo.saveIdentity(id, {
      'expectedVersion': 0,
      'name': 'Coffee Shop Updated',
      'description': 'Demo project',
      'designTargets': ['web'],
    });

    expect(saved.version, 1);
    expect(saved.concurrencyToken, token);
    expect(saved.name, 'Coffee Shop Updated');
    expect(calls, contains('PUT /api/projects/$id/drafts/current'));
  });

  test('Existing draft preserves sections and concurrency token', () async {
    final oldDraft = <String, dynamic>{
      'identity': {'name': 'Old Name'},
      'navigation': {'initialRoute': '/home'},
      'features': [
        {'id': 'feature-1', 'name': 'Orders'},
      ],
    };

    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/projects/$id') {
        return jsonResponse(project(), 200);
      }

      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$id/drafts/current') {
        return jsonResponse({
          'projectId': id,
          'version': 3,
          'concurrencyToken': token,
          'draft': oldDraft,
        }, 200);
      }

      if (request.method == 'PUT' &&
          request.url.path == '/api/projects/$id/drafts/current') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);

        final draft = body['draft'] as Map<String, dynamic>;
        expect((draft['navigation'] as Map)['initialRoute'], '/home');
        expect((draft['features'] as List).length, 1);
        expect((draft['identity'] as Map)['name'], 'New Name');

        return jsonResponse({
          'projectId': id,
          'version': 4,
          'concurrencyToken': 'new-token',
          'draft': draft,
        }, 200);
      }

      return jsonResponse({'title': 'Unexpected request'}, 404);
    });

    final repo = HttpProjectsRepository(ApiClient(client));
    final saved = await repo.saveIdentity(id, {
      'expectedVersion': 3,
      'name': 'New Name',
    });

    expect(saved.version, 4);
    expect(saved.concurrencyToken, 'new-token');
    expect(saved.rawDraft['navigation'], isNotNull);
    expect(saved.name, 'New Name');

    expect(
      () =>
          repo.saveIdentity(id, {'expectedVersion': 2, 'name': 'Stale Update'}),
      throwsA(isA<StateError>()),
    );
  });
}
