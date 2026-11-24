import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/http_projects_repository.dart';

void main() {
  group('REQVIORA .NET 10 Project API Contract', () {
    test('Create project uses the current Backend API contract', () async {
      final calls = <String>[];

      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');

        if (request.method == 'POST') {
          expect(request.url.path, '/api/projects');
          expect(request.headers.containsKey('Idempotency-Key'), isTrue);

          final body = jsonDecode(request.body) as Map<String, dynamic>;

          expect(body['name'], 'Coffee Shop');
          expect(body['description'], 'Demo');
          expect(body['industry'], 'Food & Beverage');
          expect(body['primaryPlatform'], 'web');

          expect(body.containsKey('designTargets'), isFalse);
          expect(body.containsKey('category'), isFalse);

          return http.Response(
            jsonEncode({
              'id': 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
              'name': body['name'],
              'description': body['description'],
              'ownerId': 'd5859ac2-7a39-4f5a-b937-5f1b2b592222',
              'createdAt': '2026-11-20T10:00:00Z',
              'lastModifiedAt': null,
              'industry': body['industry'],
              'primaryPlatform': body['primaryPlatform'],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = HttpProjectsRepository(ApiClient(client));

      final project = await repo.create(
        name: 'Coffee Shop',
        description: 'Demo',
        category: 'Food & Beverage',
        designTargets: ['web'],
      );

      expect(project.id, 'd5859ac2-7a39-4f5a-b937-5f1b2b591111');
      expect(project.name, 'Coffee Shop');
      expect(project.status, 'active');
      expect(project.updatedAt.year, 2026);

      expect(calls.single, 'POST /api/projects');
    });

    test('Project list uses the current Backend API contract', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/projects');

        return http.Response(
          jsonEncode([
            {
              'id': 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
              'name': 'College Management',
              'description': 'College application',
              'ownerId': 'd5859ac2-7a39-4f5a-b937-5f1b2b592222',
              'createdAt': '2026-11-20T10:00:00Z',
              'lastModifiedAt': null,
              'industry': 'Education',
              'primaryPlatform': 'web',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = HttpProjectsRepository(ApiClient(client));

      final projects = await repo.list();

      expect(projects.length, 1);
      expect(projects.first.name, 'College Management');
      expect(projects.first.status, 'active');
    });
  });
}
