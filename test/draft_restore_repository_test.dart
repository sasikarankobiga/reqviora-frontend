import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/draft_restore_repository.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const token = '22222222-2222-4222-8222-222222222222';
const newToken = '33333333-3333-4333-8333-333333333333';
const otherId = '44444444-4444-4444-8444-444444444444';

Map<String, dynamic> draft({
  int version = 5,
  String concurrencyToken = token,
  String project = projectId,
  String? approvedId,
}) => {
  'projectId': project,
  'version': version,
  'concurrencyToken': concurrencyToken,
  'approvedRevisionId': approvedId,
  'draft': {'features': []},
};

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  DraftRestoreRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);

    return DraftRestoreRepository(api);
  }

  test('Loads authenticated current draft state', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects/$projectId/drafts/current');
      expect(request.headers['Authorization'], 'Bearer test-session');

      return response(draft());
    });

    final current = await repo.current(projectId);

    expect(current.version, 5);
    expect(current.concurrencyToken, token);
    expect(current.approved, isFalse);
  });

  test('Restore creates a new version using exact token', () async {
    final repo = repository((request) async {
      if (request.method == 'GET') {
        return response(draft());
      }

      expect(request.method, 'POST');

      expect(
        request.url.path,
        '/api/projects/$projectId/drafts/versions/2/restore',
      );

      expect(jsonDecode(request.body), {'expectedConcurrencyToken': token});

      return response(draft(version: 6, concurrencyToken: newToken));
    });

    final current = await repo.current(projectId);

    final restored = await repo.restore(
      current: current,
      historicalVersion: 2,
      confirmed: true,
    );

    expect(restored.version, 6);
    expect(restored.concurrencyToken, newToken);
    expect(restored.approved, isFalse);
  });

  test('Restore requires explicit confirmation', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');

      return response(draft());
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: false),
      throwsArgumentError,
    );
  });

  test('Approved draft restoration is blocked', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');

      return response(draft(approvedId: otherId));
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsStateError,
    );
  });

  test('Rejects invalid and current version selection', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');

      return response(draft());
    });

    final current = await repo.current(projectId);

    for (final version in [-1, 0, 5, 6]) {
      await expectLater(
        repo.restore(
          current: current,
          historicalVersion: version,
          confirmed: true,
        ),
        throwsArgumentError,
      );
    }
  });

  test('Rejects unauthenticated requests', () async {
    authSession.signOut();

    final repo = repository((_) async {
      fail('Anonymous request must not reach API');
    });

    await expectLater(repo.current(projectId), throwsA(isA<ApiException>()));
  });

  test('Rejects invalid project identifiers', () async {
    final repo = repository((_) async {
      fail('Invalid project ID must not reach API');
    });

    await expectLater(repo.current('invalid'), throwsArgumentError);
  });

  test('Rejects cross-project current draft', () async {
    final repo = repository((_) async {
      return response(draft(project: otherId));
    });

    await expectLater(repo.current(projectId), throwsFormatException);
  });

  test('Rejects invalid concurrency token', () async {
    final repo = repository((_) async {
      return response(draft(concurrencyToken: 'invalid'));
    });

    await expectLater(repo.current(projectId), throwsFormatException);
  });

  test('Preserves server concurrency conflict', () async {
    var writes = 0;

    final repo = repository((request) async {
      if (request.method == 'GET') {
        return response(draft());
      }

      writes++;

      return response({'title': 'Conflict'}, 409);
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );

    expect(writes, 1);
  });

  test('Preserves server permission denial', () async {
    final repo = repository((request) async {
      if (request.method == 'GET') {
        return response(draft());
      }

      return response({'title': 'Forbidden'}, 403);
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Rejects incorrect restored version receipt', () async {
    final repo = repository((request) async {
      if (request.method == 'GET') {
        return response(draft());
      }

      return response(draft(version: 2, concurrencyToken: newToken));
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsFormatException,
    );
  });

  test('Rejects unchanged concurrency token', () async {
    final repo = repository((request) async {
      if (request.method == 'GET') {
        return response(draft());
      }

      return response(draft(version: 6));
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsFormatException,
    );
  });

  test('Session change invalidates previous restore state', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');

      return response(draft());
    });

    final current = await repo.current(projectId);

    authSession.signIn('another-session');

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsA(isA<ApiException>()),
    );
  });

  test('Rejects stale restore response after session change', () async {
    final repo = repository((request) async {
      if (request.method == 'GET') {
        return response(draft());
      }

      authSession.signIn('another-session');

      return response(draft(version: 6, concurrencyToken: newToken));
    });

    final current = await repo.current(projectId);

    await expectLater(
      repo.restore(current: current, historicalVersion: 2, confirmed: true),
      throwsA(isA<ApiException>()),
    );
  });
}
