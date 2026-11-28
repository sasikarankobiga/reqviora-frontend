import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/mcp_integration/data/repositories/mcp_grant_repository.dart';
import 'package:reqviora_frontend/features/mcp_integration/domain/mcp_access_grant.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const revisionId = '22222222-2222-4222-8222-222222222222';
  const ownerId = '33333333-3333-4333-8333-333333333333';
  const grantId = '44444444-4444-4444-8444-444444444444';

  McpGrantRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    return McpGrantRepository(api);
  }

  http.Response response(Object? value, [int status = 200]) => http.Response(
    value == null ? '' : jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> grant({String state = 'active'}) => {
    'id': grantId,
    'projectId': projectId,
    'approvedRevisionId': revisionId,
    'ownerId': ownerId,
    'createdAt': '2026-11-27T08:00:00Z',
    'expiresAt': '2026-12-27T08:00:00Z',
    'revokedAt': state == 'revoked' ? '2026-11-27T09:00:00Z' : null,
    'revokedBy': state == 'revoked' ? ownerId : null,
    'revocationReason': state == 'revoked' ? 'No longer required' : null,
    'state': state,
  };

  test('loads approved revisions for the project', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/projects/$projectId/approvals');
      return response([
        {'revisionId': revisionId, 'projectId': projectId, 'draftVersion': 7},
      ]);
    });

    final revisions = await repo.approvedRevisions(projectId);
    expect(revisions.single.revisionId, revisionId);
    expect(revisions.single.draftVersion, 7);
  });

  test('lists metadata without credential fields', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/projects/$projectId/mcp/grants');
      expect(request.url.queryParameters, {'page': '1', 'pageSize': '50'});
      return response({
        'page': 1,
        'pageSize': 50,
        'total': 1,
        'items': [grant()],
      });
    });

    final page = await repo.list(projectId);
    expect(
      page.items.single.statusAt(DateTime.utc(2026, 11, 27)),
      McpGrantStatus.active,
    );
  });

  test('creates an approved-revision-bound grant', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/projects/$projectId/mcp/grants');
      expect(jsonDecode(request.body), {
        'approvedRevisionId': revisionId,
        'lifetimeMinutes': 30,
      });
      return response({
        'grant': grant(),
        'credential': 'one-time-credential',
      }, 201);
    });

    final created = await repo.create(
      projectId: projectId,
      approvedRevisionId: revisionId,
      lifetime: const Duration(minutes: 30),
    );
    expect(created.grant.revisionId, revisionId);
    expect(created.credential.take(), 'one-time-credential');
    expect(created.credential.take(), isNull);
  });

  test('revokes a grant with a required reason', () async {
    final repo = repository((request) async {
      expect(
        request.url.path,
        '/api/projects/$projectId/mcp/grants/$grantId/revoke',
      );
      expect(jsonDecode(request.body), {'reason': 'No longer required'});
      return response(grant(state: 'revoked'));
    });

    final result = await repo.revoke(
      projectId: projectId,
      grantId: grantId,
      reason: ' No longer required ',
    );
    expect(result.revokedAt, isNotNull);
  });

  test('rejects unsupported grant lifetimes locally', () async {
    final repo = repository((request) async {
      fail('Invalid lifetime must not reach the API');
    });
    for (final lifetime in [
      const Duration(minutes: 4),
      const Duration(days: 31),
      const Duration(seconds: 301),
    ]) {
      await expectLater(
        repo.create(
          projectId: projectId,
          approvedRevisionId: revisionId,
          lifetime: lifetime,
        ),
        throwsArgumentError,
      );
    }
  });

  test('rejects cross-project revision and grant metadata', () async {
    var approvals = true;
    final repo = repository((request) async {
      if (approvals) {
        return response([
          {'revisionId': revisionId, 'projectId': ownerId, 'draftVersion': 1},
        ]);
      }
      return response({
        'page': 1,
        'pageSize': 50,
        'total': 1,
        'items': [
          {...grant(), 'projectId': ownerId},
        ],
      });
    });
    await expectLater(repo.approvedRevisions(projectId), throwsFormatException);
    approvals = false;
    await expectLater(repo.list(projectId), throwsFormatException);
  });

  test('rejects malformed optional grant metadata as a format error', () async {
    for (final field in ['ownerId', 'revokedBy', 'revocationReason']) {
      final repo = repository(
        (request) async => response({
          'page': 1,
          'pageSize': 50,
          'total': 1,
          'items': [
            {...grant(), field: 42},
          ],
        }),
      );

      await expectLater(repo.list(projectId), throwsFormatException);
    }
  });

  test('preserves permission denial and disabled service responses', () async {
    var status = 403;
    final repo = repository(
      (request) async => response({'title': 'Denied'}, status),
    );
    await expectLater(
      repo.list(projectId),
      throwsA(
        isA<ApiException>().having((value) => value.statusCode, 'status', 403),
      ),
    );
    status = 404;
    await expectLater(
      repo.list(projectId),
      throwsA(
        isA<ApiException>().having((value) => value.statusCode, 'status', 404),
      ),
    );
  });
}
