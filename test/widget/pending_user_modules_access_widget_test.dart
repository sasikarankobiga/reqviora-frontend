import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/mcp_integration/data/repositories/mcp_grant_repository.dart';
import 'package:reqviora_frontend/features/mcp_integration/presentation/widgets/mcp_grants_dialog.dart';
import 'package:reqviora_frontend/features/projects/data/project_invitations_repository.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_invitations_dialog.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const revisionId = '22222222-2222-4222-8222-222222222222';
const ownerId = '33333333-3333-4333-8333-333333333333';
const editorId = '44444444-4444-4444-8444-444444444444';

void main() {
  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  testWidgets('connected MCP grant dialog renders approved revision metadata', (
    tester,
  ) async {
    authSession.signIn('test-token');
    addTearDown(authSession.signOut);
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/approvals')) {
          return response([
            {
              'projectId': projectId,
              'revisionId': revisionId,
              'draftVersion': 4,
            },
          ]);
        }
        return response({'page': 1, 'pageSize': 50, 'total': 0, 'items': []});
      }),
    );
    addTearDown(api.dispose);
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: McpGrantsDialog(
          projectId: projectId,
          repository: McpGrantRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MCP Developer Handoff'), findsOneWidget);
    expect(find.textContaining('fixed read-only MCP V1'), findsOneWidget);
    expect(find.textContaining('v4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner sees connected invitation list and invite action', (
    tester,
  ) async {
    final membersApi = ApiClient(
      MockClient(
        (_) async => response([
          {'userId': ownerId, 'role': 'Owner', 'joinedAtUtc': null},
        ]),
      ),
    );
    final invitationsApi = ApiClient(
      MockClient(
        (_) async => response([
          {
            'id': revisionId,
            'projectId': projectId,
            'recipientEmail': 'person@example.com',
            'role': 'Viewer',
            'status': 'Pending',
            'createdBy': ownerId,
            'createdAt': '2026-11-27T08:00:00Z',
            'expiresAt': '2026-11-30T08:00:00Z',
            'supersedesInvitationId': null,
          },
        ]),
      ),
    );
    addTearDown(membersApi.dispose);
    addTearDown(invitationsApi.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectInvitationsDialog(
          projectId: projectId,
          actorId: ownerId,
          members: ProjectMembersRepository(membersApi),
          invitations: ProjectInvitationsRepository(invitationsApi),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('person@example.com'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
  });

  testWidgets('editor cannot load or mutate owner invitation data', (
    tester,
  ) async {
    final membersApi = ApiClient(
      MockClient(
        (_) async => response([
          {'userId': ownerId, 'role': 'Owner', 'joinedAtUtc': null},
          {'userId': editorId, 'role': 'Editor', 'joinedAtUtc': null},
        ]),
      ),
    );
    var invitationCalls = 0;
    final invitationsApi = ApiClient(
      MockClient((_) async {
        invitationCalls++;
        return response([]);
      }),
    );
    addTearDown(membersApi.dispose);
    addTearDown(invitationsApi.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectInvitationsDialog(
          projectId: projectId,
          actorId: editorId,
          members: ProjectMembersRepository(membersApi),
          invitations: ProjectInvitationsRepository(invitationsApi),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Only the project owner'), findsOneWidget);
    expect(find.text('Invite'), findsNothing);
    expect(invitationCalls, 0);
  });

  testWidgets('connected MCP credential is removed on logout', (tester) async {
    authSession.signIn('test-token');
    addTearDown(authSession.signOut);
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/approvals')) {
          return response([
            {
              'projectId': projectId,
              'revisionId': revisionId,
              'draftVersion': 4,
            },
          ]);
        }
        if (request.method == 'GET') {
          return response({'page': 1, 'pageSize': 50, 'total': 0, 'items': []});
        }
        return response({
          'grant': {
            'id': editorId,
            'projectId': projectId,
            'approvedRevisionId': revisionId,
            'ownerId': ownerId,
            'createdAt': '2026-11-27T08:00:00Z',
            'expiresAt': '2026-12-27T08:00:00Z',
            'revokedAt': null,
            'revokedBy': null,
            'revocationReason': null,
            'state': 'active',
          },
          'credential': 'one-time-connected-credential',
        }, 201);
      }),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: McpGrantsDialog(
          projectId: projectId,
          repository: McpGrantRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create grant'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mcp-live-credential')), findsOneWidget);
    authSession.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mcp-live-credential')), findsNothing);
    expect(find.text('one-time-connected-credential'), findsNothing);
  });
}
