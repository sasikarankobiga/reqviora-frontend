import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const revisionId = '22222222-2222-4222-8222-222222222222';
  const exportId = '33333333-3333-4333-8333-333333333333';

  test('Creates official export from approved revision', () async {
    var requests = 0;

    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/projects/$projectId/exports/from-revision/$revisionId',
      );
      expect(jsonDecode(request.body), isEmpty);

      requests++;

      return http.Response(
        jsonEncode({
          'exportId': exportId,
          'approvedRevisionId': revisionId,
          'archiveBytes': 4,
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });

    final repo = WorkspaceRepository(ApiClient(client));
    final result = await repo.createOfficialExport(
      projectId,
      revisionId,
    );

    expect(requests, 1);
    expect(result['exportId'], exportId);
    expect(result['approvedRevisionId'], revisionId);

    client.close();
  });

  test('Downloads actual ZIP bytes from export ID', () async {
    const zipBytes = <int>[80, 75, 3, 4];

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/projects/$projectId/exports/$exportId/download',
      );

      return http.Response.bytes(
        zipBytes,
        200,
        headers: {'content-type': 'application/zip'},
      );
    });

    final repo = WorkspaceRepository(ApiClient(client));

    final bytes = await repo.downloadOfficialExport(
      projectId,
      exportId,
    );

    expect(bytes, zipBytes);
    client.close();
  });

  test('Missing revision ID prevents export request', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.createOfficialExport(projectId, ''),
      throwsArgumentError,
    );

    expect(requests, 0);
    client.close();
  });

  test('Missing export ID prevents download request', () async {
    var requests = 0;

    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    });

    final repo = WorkspaceRepository(ApiClient(client));

    await expectLater(
      repo.downloadOfficialExport(projectId, ''),
      throwsArgumentError,
    );

    expect(requests, 0);
    client.close();
  });
}