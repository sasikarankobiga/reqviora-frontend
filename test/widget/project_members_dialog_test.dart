import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_members_dialog.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const ownerId = '22222222-2222-4222-8222-222222222222';
  const editorId = '33333333-3333-4333-8333-333333333333';
  const viewerId = '44444444-4444-4444-8444-444444444444';
  const newId = '55555555-5555-4555-8555-555555555555';

  late List<Map<String, dynamic>> members;
  late List<http.Request> writes;

  setUp(() {
    members = [
      {'userId': ownerId, 'role': 'Owner'},
      {'userId': editorId, 'role': 'Editor'},
      {'userId': viewerId, 'role': 'Viewer'},
    ];

    writes = [];
  });

  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<void> open(
    WidgetTester tester,
    String? actorId, {
    bool deny = false,
  }) async {
    final api = ApiClient(
      MockClient((request) async {
        if (deny) {
          return response({'title': 'Forbidden'}, 403);
        }

        if (request.method == 'GET') {
          return response(members);
        }

        writes.add(request);

        final id = request.url.pathSegments.last;

        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map;
          final updated = <String, dynamic>{'userId': id, 'role': body['role']};

          members.removeWhere((member) => member['userId'] == id);
          members.add(updated);

          return response(updated);
        }

        if (request.method == 'DELETE') {
          members.removeWhere((member) => member['userId'] == id);
          return http.Response('', 204);
        }

        return response({'title': 'Unexpected request'}, 400);
      }),
    );

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectMembersDialog(
            projectId: projectId,
            actorId: actorId,
            repository: ProjectMembersRepository(api),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Owner receives member management controls', (tester) async {
    await open(tester, ownerId);

    expect(find.text('Add Registered Member'), findsOneWidget);
    expect(find.text('Make Viewer'), findsOneWidget);
    expect(find.text('Make Editor'), findsOneWidget);
    expect(find.text('Remove'), findsNWidgets(2));
  });

  testWidgets('Editor receives read-only membership view', (tester) async {
    await open(tester, editorId);

    expect(find.textContaining('Read-only membership view'), findsOneWidget);
    expect(find.text('Add Member'), findsNothing);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Make Viewer'), findsNothing);
    expect(writes, isEmpty);
  });

  testWidgets('Viewer cannot manage project members', (tester) async {
    await open(tester, viewerId);

    expect(find.text('Add Member'), findsNothing);
    expect(find.text('Make Editor'), findsNothing);
    expect(find.text('Remove'), findsNothing);
    expect(writes, isEmpty);
  });

  testWidgets('Unknown actor cannot manage project members', (tester) async {
    await open(tester, null);

    expect(find.text('Add Member'), findsNothing);
    expect(find.text('Remove'), findsNothing);
    expect(writes, isEmpty);
  });

  testWidgets('Owner can add a registered Viewer', (tester) async {
    await open(tester, ownerId);

    final input = find.byKey(const ValueKey('member-user-id'));

    await tester.ensureVisible(input);
    await tester.enterText(input, newId);

    await tap(tester, find.byKey(const ValueKey('add-project-member')));
    await tap(tester, find.text('Confirm'));

    expect(writes.length, 1);
    expect(writes.single.method, 'PUT');
    expect(writes.single.url.pathSegments.last, newId);
    expect(jsonDecode(writes.single.body), {'role': 'Viewer'});
    expect(find.text('Project member added.'), findsOneWidget);
  });

  testWidgets('Invalid user ID does not send a write request', (tester) async {
    await open(tester, ownerId);

    final input = find.byKey(const ValueKey('member-user-id'));

    await tester.ensureVisible(input);
    await tester.enterText(input, 'invalid-id');

    await tap(tester, find.byKey(const ValueKey('add-project-member')));

    expect(find.text('Enter a valid registered user ID.'), findsOneWidget);

    expect(writes, isEmpty);
  });

  testWidgets('Owner can change Editor to Viewer', (tester) async {
    await open(tester, ownerId);

    await tap(tester, find.text('Make Viewer'));
    await tap(tester, find.text('Confirm'));

    expect(writes.length, 1);
    expect(writes.single.method, 'PUT');
    expect(writes.single.url.pathSegments.last, editorId);
    expect(jsonDecode(writes.single.body), {'role': 'Viewer'});
    expect(find.text('Member role updated.'), findsOneWidget);
  });

  testWidgets('Owner can remove a member after confirmation', (tester) async {
    await open(tester, ownerId);

    await tap(tester, find.text('Remove').first);
    await tap(tester, find.text('Confirm'));

    expect(writes.length, 1);
    expect(writes.single.method, 'DELETE');
    expect(writes.single.url.pathSegments.last, editorId);
    expect(find.text('Project member removed.'), findsOneWidget);
  });

  testWidgets('Cancelling removal preserves membership', (tester) async {
    await open(tester, ownerId);

    await tap(tester, find.text('Remove').first);
    await tap(tester, find.text('Cancel'));

    expect(writes, isEmpty);
    expect(members.length, 3);
  });

  testWidgets('Server permission denial hides management controls', (
    tester,
  ) async {
    await open(tester, ownerId, deny: true);

    expect(
      find.text('You do not have permission for this action.'),
      findsOneWidget,
    );

    expect(find.text('Add Member'), findsNothing);
    expect(find.text('Remove'), findsNothing);
    expect(writes, isEmpty);
  });
}
