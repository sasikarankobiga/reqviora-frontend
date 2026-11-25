import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const validationId = '22222222-2222-4222-8222-222222222222';
  const token = '33333333-3333-4333-8333-333333333333';

  http.Response reply(Object data, int status) => http.Response(
        jsonEncode(data),
        status,
        headers: {'content-type': 'application/json'},
      );

  test('Approval sends validation ID and current concurrency token',
      () async {
    var approvals = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return reply({
          'version': 5,
          'concurrencyToken': token,
          'draft': {},
        }, 200);
      }

      if (request.method == 'POST' &&
          request.url.path == '/api/projects/$projectId/approvals') {
        approvals++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['expectedConcurrencyToken'], token);
        expect(body['validationRunId'], validationId);
        return reply({'revisionId': 'approved-revision-1'}, 201);
      }

      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final result = await repo.approveValidatedDraft(
      projectId, 5, validationId,
    );

    expect(approvals, 1);
    expect(result['revisionId'], 'approved-revision-1');
    client.close();
  });

  test('Stale draft prevents approval request', () async {
    var approvals = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return reply({
          'version': 6,
          'concurrencyToken': token,
          'draft': {},
        }, 200);
      }

      approvals++;
      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.approveValidatedDraft(projectId, 5, validationId),
      throwsStateError,
    );

    expect(approvals, 0);
    client.close();
  });

  test('Missing concurrency token prevents approval', () async {
    var approvals = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return reply({'version': 5, 'draft': {}}, 200);
      }

      approvals++;
      return reply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.approveValidatedDraft(projectId, 5, validationId),
      throwsStateError,
    );

    expect(approvals, 0);
    client.close();
  });
}