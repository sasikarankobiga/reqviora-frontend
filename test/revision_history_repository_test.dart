import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/revision_history_repository.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const revisionId = '22222222-2222-4222-8222-222222222222';
const draftId = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> blueprint({String ownerProject = projectId}) => {
  'projectId': ownerProject,
  'screens': [],
  'components': [],
};

Map<String, dynamic> approved({
  String id = revisionId,
  String ownerProject = projectId,
}) => {
  'revisionId': id,
  'draftVersion': 3,
  'approvedAt': '2026-11-25T12:00:00Z',
  'blueprint': blueprint(ownerProject: ownerProject),
};

Map<String, dynamic> draft({bool hasBlueprint = true}) => {
  'draftVersionId': draftId,
  'version': 2,
  'savedAt': '2026-11-24T12:00:00Z',
  'blueprint': hasBlueprint ? blueprint() : null,
};

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  RevisionHistoryRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);

    return RevisionHistoryRepository(api);
  }

  http.Response response(Object value, [int status = 200]) =>
      http.Response(jsonEncode(value), status);

  test('Loads approved Blueprint history', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects/$projectId/blueprints/approved');

      return response([approved()]);
    });

    final history = await repo.approvedHistory(projectId);

    expect(history.single.id, revisionId);
    expect(history.single.version, 3);
    expect(history.single.approved, isTrue);
    expect(history.single.blueprint, isNotNull);
  });

  test('Loads draft version history', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects/$projectId/drafts/versions');

      return response([draft()]);
    });

    final history = await repo.draftHistory(projectId);

    expect(history.single.id, draftId);
    expect(history.single.version, 2);
    expect(history.single.approved, isFalse);
  });

  test('Draft version without Blueprint remains valid', () async {
    final repo = repository((_) async {
      return response([draft(hasBlueprint: false)]);
    });

    final history = await repo.draftHistory(projectId);

    expect(history.single.blueprint, isNull);
  });

  test('Loads exact approved historical Blueprint', () async {
    final repo = repository((request) async {
      expect(
        request.url.path,
        '/api/projects/$projectId/blueprints/approved/$revisionId',
      );

      return response(approved());
    });

    final item = await repo.approvedRevision(projectId, revisionId);

    expect(item.id, revisionId);
  });

  test('Rejects cross-project historical Blueprint', () async {
    final repo = repository((_) async {
      return response(approved(ownerProject: draftId));
    });

    await expectLater(
      repo.approvedRevision(projectId, revisionId),
      throwsFormatException,
    );
  });

  test('Rejects mismatched revision identity', () async {
    final repo = repository((_) async {
      return response(approved(id: draftId));
    });

    await expectLater(
      repo.approvedRevision(projectId, revisionId),
      throwsFormatException,
    );
  });

  test('Rejects duplicate historical records', () async {
    final repo = repository((_) async {
      return response([approved(), approved()]);
    });

    await expectLater(repo.approvedHistory(projectId), throwsFormatException);
  });

  test('Rejects invalid project ID before HTTP', () async {
    final repo = repository((_) async {
      fail('Invalid project ID must not reach the API');
    });

    await expectLater(
      repo.approvedHistory('../other-project'),
      throwsArgumentError,
    );
  });

  test('Preserves server permission rejection', () async {
    final repo = repository((_) async {
      return response({'title': 'Forbidden'}, 403);
    });

    await expectLater(
      repo.draftHistory(projectId),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Session change prevents stale history delivery', () async {
    final repo = repository((_) async {
      authSession.signIn('different-session');
      return response([approved()]);
    });

    await expectLater(
      repo.approvedHistory(projectId),
      throwsA(isA<ApiException>()),
    );
  });
}
