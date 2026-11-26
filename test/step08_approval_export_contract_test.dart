import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const token = '22222222-2222-4222-8222-222222222222';
  const revisionId = '33333333-3333-4333-8333-333333333333';
  const exportId = '44444444-4444-4444-8444-444444444444';

  http.Response jsonReply(Object value, int status) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Step 08 validation sends the current draft token', () async {
    var validationCalls = 0;

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return jsonReply({'version': 4, 'concurrencyToken': token}, 200);
      }

      if (request.method == 'POST' &&
          path == '/api/projects/$projectId/blueprints/validate') {
        validationCalls++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], token);

        return jsonReply({
          'id': 'validation-run-1',
          'passed': true,
          'findings': [],
        }, 200);
      }

      return jsonReply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final result = await repo.validate(projectId);

    expect(result['passed'], true);
    expect(result['id'], 'validation-run-1');
    expect(validationCalls, 1);

    client.close();
  });

  test('Step 08 approval uses validated revision and token', () async {
    var approvals = 0;

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return jsonReply({'version': 4, 'concurrencyToken': token}, 200);
      }

      if (request.method == 'POST' &&
          path == '/api/projects/$projectId/approvals') {
        approvals++;

        final body = jsonDecode(request.body) as Map<String, dynamic>;

        expect(body['expectedConcurrencyToken'], token);
        expect(body['validationRunId'], 'validation-run-1');

        return jsonReply({'revisionId': revisionId}, 200);
      }

      return jsonReply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final result = await repo.approveValidatedDraft(
      projectId,
      4,
      'validation-run-1',
    );

    expect(result['revisionId'], revisionId);
    expect(approvals, 1);

    client.close();
  });

  test('Stale draft cannot request approval', () async {
    var approvalCalls = 0;

    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/projects/$projectId/drafts/current') {
        return jsonReply({'version': 5, 'concurrencyToken': token}, 200);
      }

      if (request.url.path.endsWith('/approvals')) {
        approvalCalls++;
      }

      return jsonReply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.approveValidatedDraft(projectId, 4, 'validation-run-1'),
      throwsA(isA<StateError>()),
    );

    expect(approvalCalls, 0);

    client.close();
  });

  test('Official export uses approved revision and export ID', () async {
    var createCalls = 0;
    var downloadCalls = 0;
    final zip = <int>[80, 75, 5, 6, ...List<int>.filled(18, 0)];

    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'POST' &&
          path ==
              '/api/projects/$projectId/exports/from-revision/$revisionId') {
        createCalls++;

        return jsonReply({'exportId': exportId}, 200);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/exports/$exportId/download') {
        downloadCalls++;

        return http.Response.bytes(
          zip,
          200,
          headers: {'content-type': 'application/zip'},
        );
      }

      return jsonReply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final metadata = await repo.createOfficialExport(projectId, revisionId);

    expect(metadata['exportId'], exportId);

    final bytes = await repo.downloadOfficialExport(projectId, exportId);

    expect(bytes, zip);
    expect(createCalls, 1);
    expect(downloadCalls, 1);

    client.close();
  });

  test('Export without approved revision is rejected', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return jsonReply({'error': 'Unexpected request'}, 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.createOfficialExport(projectId, ''),
      throwsArgumentError,
    );

    expect(requests, 0);

    client.close();
  });
}
