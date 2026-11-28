import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/project_invitations_repository.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/projects/domain/project_invitation.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_invitation_response_page.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const invitationId = '22222222-2222-4222-8222-222222222222';
  const ownerId = '33333333-3333-4333-8333-333333333333';
  const userId = '44444444-4444-4444-8444-444444444444';
  const token = 'abcdefghijklmnopqrstuvwxyz1234567890';

  ProjectInvitationsRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    return ProjectInvitationsRepository(api);
  }

  http.Response response(Object? value, [int status = 200]) => http.Response(
    value == null ? '' : jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> invitation({
    String id = invitationId,
    String project = projectId,
    String status = 'Pending',
  }) => {
    'id': id,
    'projectId': project,
    'recipientEmail': 'person@example.com',
    'role': 'Viewer',
    'status': status,
    'createdBy': ownerId,
    'createdAt': '2026-11-27T08:00:00Z',
    'expiresAt': '2026-11-30T08:00:00Z',
    'acceptedBy': null,
    'acceptedAt': null,
    'rejectedBy': null,
    'rejectedAt': null,
    'revokedBy': null,
    'revokedAt': null,
    'supersedesInvitationId': null,
  };

  test('lists project invitations from owner route', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/projects/$projectId/invitations');
      return response([invitation()]);
    });

    final result = await repo.list(projectId);
    expect(result.single.status, ProjectInvitationStatus.pending);
    expect(result.single.role, ProjectMemberRole.viewer);
  });

  test('creates invitation with authoritative request DTO', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/projects/$projectId/invitations');
      expect(jsonDecode(request.body), {
        'recipientEmail': 'person@example.com',
        'role': 'Editor',
      });
      return response({...invitation(), 'role': 'Editor'}, 201);
    });

    final result = await repo.create(
      projectId: projectId,
      recipientEmail: ' person@example.com ',
      role: ProjectMemberRole.editor,
    );
    expect(result.role, ProjectMemberRole.editor);
  });

  test('resends and revokes through exact lifecycle routes', () async {
    var calls = 0;
    final repo = repository((request) async {
      calls++;
      expect(request.method, 'POST');
      if (calls == 1) {
        expect(
          request.url.path,
          '/api/projects/$projectId/invitations/$invitationId/resend',
        );
        return response(invitation());
      }
      expect(
        request.url.path,
        '/api/projects/$projectId/invitations/$invitationId/revoke',
      );
      return response(invitation(status: 'Revoked'));
    });

    await repo.resend(projectId: projectId, invitationId: invitationId);
    final revoked = await repo.revoke(
      projectId: projectId,
      invitationId: invitationId,
    );
    expect(revoked.status, ProjectInvitationStatus.revoked);
  });

  test('accepts invitation token and validates membership', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/project-invitations/accept');
      expect(jsonDecode(request.body), {'token': token});
      return response({
        'projectId': projectId,
        'userId': userId,
        'role': 'Viewer',
        'joinedAt': '2026-11-27T09:00:00Z',
      });
    });

    final result = await repo.accept(token);
    expect(result.projectId, projectId);
    expect(result.userId, userId);
  });

  test('rejects invitation token through response route', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/project-invitations/reject');
      return response(invitation(status: 'Rejected'));
    });

    expect((await repo.reject(token)).status, ProjectInvitationStatus.rejected);
  });

  test('rejects invalid email, owner role, and short token locally', () async {
    final repo = repository((request) async {
      fail('Invalid request must not reach the API');
    });

    await expectLater(
      repo.create(
        projectId: projectId,
        recipientEmail: 'invalid',
        role: ProjectMemberRole.viewer,
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.create(
        projectId: projectId,
        recipientEmail: 'a@example.com',
        role: ProjectMemberRole.owner,
      ),
      throwsArgumentError,
    );
    await expectLater(repo.accept('short'), throwsArgumentError);
  });

  test('rejects duplicate and cross-project invitation responses', () async {
    var crossed = false;
    final repo = repository((request) async {
      if (crossed) {
        return response([invitation(project: userId)]);
      }
      return response([invitation(), invitation()]);
    });
    await expectLater(repo.list(projectId), throwsFormatException);
    crossed = true;
    await expectLater(repo.list(projectId), throwsFormatException);
  });

  test('rejects malformed recipient email in an invitation response', () async {
    final repo = repository(
      (request) async => response([
        {...invitation(), 'recipientEmail': 'person@localhost'},
      ]),
    );

    await expectLater(repo.list(projectId), throwsFormatException);
  });

  test('expired invitations cannot be resent or revoked', () async {
    final repo = repository(
      (request) async => response([invitation(status: 'Expired')]),
    );

    final item = (await repo.list(projectId)).single;
    expect(item.status, ProjectInvitationStatus.expired);
    expect(item.canResend, isFalse);
    expect(item.canRevoke, isFalse);
  });

  test('preserves duplicate invitation conflict', () async {
    final repo = repository(
      (request) async => response({'title': 'Duplicate'}, 409),
    );
    await expectLater(
      repo.create(
        projectId: projectId,
        recipientEmail: 'a@example.com',
        role: ProjectMemberRole.viewer,
      ),
      throwsA(
        isA<ApiException>().having((value) => value.statusCode, 'status', 409),
      ),
    );
  });

  test('pending deep-link token is held in memory and consumed once', () {
    pendingInvitationResponse.capture('short');
    expect(pendingInvitationResponse.take(), isNull);
    pendingInvitationResponse.capture(token);
    expect(pendingInvitationResponse.take(), token);
    expect(pendingInvitationResponse.take(), isNull);
  });
}
