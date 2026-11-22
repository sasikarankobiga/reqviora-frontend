import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/http_projects_repository.dart';

void main() {
  test(
    'Flutter REST adapter uses the .NET 10 /api/v1 project JSON contract',
    () async {
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          expect(request.headers.containsKey('Idempotency-Key'), isTrue);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['designTargets'], ['web']);
          return http.Response(
            jsonEncode({
              'projectId': 'd5859ac2-7a39-4f5a-b937-5f1b2b591111',
              'name': body['name'],
              'status': 'active',
              'currentDraftId': 'd5859ac2-7a39-4f5a-b937-5f1b2b592222',
              'updatedAt': '2026-11-20T10:00:00Z',
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
      expect(project.name, 'Coffee Shop');
      expect(calls.single, 'POST /api/v1/projects');
    },
  );
}
