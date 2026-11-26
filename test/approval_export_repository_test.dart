import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/approval_export_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const revisionId = '22222222-2222-4222-8222-222222222222';
  const validationId = '33333333-3333-4333-8333-333333333333';
  const exportId = '44444444-4444-4444-8444-444444444444';
  const token = '55555555-5555-4555-8555-555555555555';

  ApprovalExportRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));

    addTearDown(api.dispose);

    return ApprovalExportRepository(api);
  }

  http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Approval sends validated revision and concurrency token', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/projects/$projectId/approvals');

      expect(jsonDecode(request.body), {
        'expectedConcurrencyToken': token,
        'validationRunId': validationId,
      });

      return jsonResponse({
        'revisionId': revisionId,
        'validationRunId': validationId,
        'draftVersion': 3,
      }, 201);
    });

    final result = await repo.approve(
      projectId: projectId,
      expectedConcurrencyToken: token,
      validationRunId: validationId,
      explicitlyConfirmed: true,
    );

    expect(result['revisionId'], revisionId);
  });

  test('Approval requires explicit human confirmation', () async {
    final repo = repository((_) async {
      fail('Unconfirmed approval must not reach the server');
    });

    await expectLater(
      repo.approve(
        projectId: projectId,
        expectedConcurrencyToken: token,
        validationRunId: validationId,
        explicitlyConfirmed: false,
      ),
      throwsArgumentError,
    );
  });

  test('Approval requires concurrency token', () async {
    final repo = repository((_) async {
      fail('Invalid approval must not reach the server');
    });

    await expectLater(
      repo.approve(
        projectId: projectId,
        expectedConcurrencyToken: '',
        validationRunId: validationId,
        explicitlyConfirmed: true,
      ),
      throwsArgumentError,
    );
  });

  test('Rejects invalid project identifier', () async {
    final repo = repository((_) async {
      fail('Invalid project must not reach the server');
    });

    await expectLater(repo.getRevisions('invalid'), throwsArgumentError);
  });

  test('Loads approved revision history', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects/$projectId/approvals');

      return jsonResponse([
        {'revisionId': revisionId, 'draftVersion': 3},
      ]);
    });

    final result = await repo.getRevisions(projectId);

    expect(result.single['revisionId'], revisionId);
  });

  test('Loads individual approved revision', () async {
    final repo = repository((request) async {
      expect(
        request.url.path,
        '/api/projects/$projectId/approvals/$revisionId',
      );

      return jsonResponse({'revisionId': revisionId, 'draftVersion': 3});
    });

    final result = await repo.getRevision(projectId, revisionId);

    expect(result['draftVersion'], 3);
  });

  test('Creates official export from approved revision', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/projects/$projectId/exports/from-revision/$revisionId',
      );

      return jsonResponse({
        'exportId': exportId,
        'approvedRevisionId': revisionId,
      }, 201);
    });

    final result = await repo.createExport(projectId, revisionId);

    expect(result['exportId'], exportId);
    expect(result['approvedRevisionId'], revisionId);
  });

  test('Loads export history', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/projects/$projectId/exports');

      return jsonResponse([
        {'exportId': exportId},
      ]);
    });

    final result = await repo.getExports(projectId);

    expect(result.single['exportId'], exportId);
  });

  test('Loads export metadata', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/projects/$projectId/exports/$exportId');

      return jsonResponse({'exportId': exportId, 'archiveBytes': 100});
    });

    final result = await repo.getExport(projectId, exportId);

    expect(result['archiveBytes'], 100);
  });

  test('Downloads response with ZIP signature', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/projects/$projectId/exports/$exportId/download',
      );

      return http.Response.bytes(
        [0x50, 0x4B, 0x03, 0x04, 1, 2, 3],
        200,
        headers: {'content-type': 'application/zip'},
      );
    });

    final bytes = await repo.downloadExport(projectId, exportId);

    expect(bytes.take(4), [0x50, 0x4B, 0x03, 0x04]);
  });

  test('Rejects invalid ZIP signature', () async {
    final repo = repository((_) async {
      return http.Response.bytes([1, 2, 3, 4], 200);
    });

    await expectLater(
      repo.downloadExport(projectId, exportId),
      throwsFormatException,
    );
  });

  test('Rejects malformed revision list', () async {
    final repo = repository((_) async {
      return jsonResponse({'invalid': true});
    });

    await expectLater(repo.getRevisions(projectId), throwsFormatException);
  });

  test('Preserves backend permission rejection', () async {
    final repo = repository((_) async {
      return jsonResponse({'message': 'Forbidden'}, 403);
    });

    await expectLater(
      repo.getExports(projectId),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Preserves stale approval conflict', () async {
    final repo = repository((_) async {
      return jsonResponse({'message': 'Draft changed'}, 409);
    });

    await expectLater(
      repo.approve(
        projectId: projectId,
        expectedConcurrencyToken: token,
        validationRunId: validationId,
        explicitlyConfirmed: true,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });
}
