import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const ownerId = '22222222-2222-4222-8222-222222222222';
  const memberId = '33333333-3333-4333-8333-333333333333';

  ProjectMembersRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    return ProjectMembersRepository(api);
  }

  http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> member(String id, String role) => {
    'userId': id,
    'role': role,
    'joinedAtUtc': null,
  };

  test('Loads owner and project members', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects/$projectId/members');

      return jsonResponse([
        member(ownerId, 'Owner'),
        member(memberId, 'Editor'),
      ]);
    });

    final result = await repo.getMembers(projectId);

    expect(result.length, 2);
    expect(result.first.isOwner, isTrue);
    expect(result.last.role, ProjectMemberRole.editor);
  });

  test('Updates an accepted member to Editor', () async {
    final repo = repository((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/projects/$projectId/members/$memberId');
      expect(jsonDecode(request.body), {'role': 'Editor'});

      return jsonResponse(member(memberId, 'Editor'));
    });

    final result = await repo.setMemberRole(
      projectId: projectId,
      memberUserId: memberId,
      role: ProjectMemberRole.editor,
    );

    expect(result.role, ProjectMemberRole.editor);
  });

  test('Updates member role to Viewer', () async {
    final repo = repository((request) async {
      expect(jsonDecode(request.body), {'role': 'Viewer'});

      return jsonResponse(member(memberId, 'Viewer'));
    });

    final result = await repo.setMemberRole(
      projectId: projectId,
      memberUserId: memberId,
      role: ProjectMemberRole.viewer,
    );

    expect(result.role, ProjectMemberRole.viewer);
  });

  test('Rejects Owner role assignment', () async {
    final repo = repository((request) async {
      fail('Must not send an unsupported role assignment');
    });

    await expectLater(
      repo.setMemberRole(
        projectId: projectId,
        memberUserId: memberId,
        role: ProjectMemberRole.owner,
      ),
      throwsArgumentError,
    );
  });

  test('Rejects invalid member ID', () async {
    final repo = repository((request) async {
      fail('Must not send invalid user ID');
    });

    await expectLater(
      repo.setMemberRole(
        projectId: projectId,
        memberUserId: 'invalid',
        role: ProjectMemberRole.editor,
      ),
      throwsArgumentError,
    );
  });

  test('Rejects invalid project ID', () async {
    final repo = repository((request) async {
      fail('Must not send invalid project ID');
    });

    await expectLater(repo.getMembers('invalid'), throwsArgumentError);
  });

  test('Removes member using DELETE and handles 204', () async {
    final repo = repository((request) async {
      expect(request.method, 'DELETE');
      expect(request.url.path, '/api/projects/$projectId/members/$memberId');

      return http.Response('', 204);
    });

    await repo.removeMember(projectId: projectId, memberUserId: memberId);
  });

  test('Preserves server permission denial', () async {
    final repo = repository((request) async {
      return jsonResponse({'title': 'Forbidden'}, 403);
    });

    await expectLater(
      repo.removeMember(projectId: projectId, memberUserId: memberId),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Handles unknown registered user', () async {
    final repo = repository((request) async {
      return jsonResponse({'title': 'Not found'}, 404);
    });

    await expectLater(
      repo.setMemberRole(
        projectId: projectId,
        memberUserId: memberId,
        role: ProjectMemberRole.viewer,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });

  test('Rejects unsupported server role', () async {
    final repo = repository((request) async {
      return jsonResponse([
        member(ownerId, 'Owner'),
        member(memberId, 'Administrator'),
      ]);
    });

    await expectLater(repo.getMembers(projectId), throwsFormatException);
  });

  test('Parses an accepted member join timestamp as UTC', () async {
    final repo = repository(
      (request) async => jsonResponse([
        member(ownerId, 'Owner'),
        {
          ...member(memberId, 'Viewer'),
          'joinedAtUtc': '2026-11-27T08:30:00+05:30',
        },
      ]),
    );

    final result = await repo.getMembers(projectId);
    expect(result.last.joinedAtUtc, DateTime.utc(2026, 11, 27, 3));
    expect(result.last.joinedAtUtc?.isUtc, isTrue);
  });

  test('Rejects duplicate members', () async {
    final repo = repository((request) async {
      return jsonResponse([
        member(ownerId, 'Owner'),
        member(memberId, 'Editor'),
        member(memberId, 'Viewer'),
      ]);
    });

    await expectLater(repo.getMembers(projectId), throwsFormatException);
  });

  test('Rejects missing project owner', () async {
    final repo = repository((request) async {
      return jsonResponse([member(memberId, 'Editor')]);
    });

    await expectLater(repo.getMembers(projectId), throwsFormatException);
  });

  test('Rejects mismatched member response', () async {
    final repo = repository((request) async {
      return jsonResponse(member(ownerId, 'Viewer'));
    });

    await expectLater(
      repo.setMemberRole(
        projectId: projectId,
        memberUserId: memberId,
        role: ProjectMemberRole.viewer,
      ),
      throwsFormatException,
    );
  });
}
