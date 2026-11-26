import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/features/mcp_integration/domain/mcp_access_grant.dart';
import 'package:reqviora_frontend/features/mcp_integration/presentation/widgets/mcp_grant_management_panel.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const revisionId = '22222222-2222-4222-8222-222222222222';
const grantId = '33333333-3333-4333-8333-333333333333';
const otherId = '44444444-4444-4444-8444-444444444444';
const expiredId = '55555555-5555-4555-8555-555555555555';
const revokedId = '66666666-6666-4666-8666-666666666666';

McpApprovedRevision revision({
  String project = projectId,
  String id = revisionId,
  int version = 5,
}) => McpApprovedRevision(
  projectId: project,
  revisionId: id,
  draftVersion: version,
);

McpAccessGrant grant({
  String id = grantId,
  String project = projectId,
  bool expired = false,
  bool revoked = false,
}) {
  final now = DateTime.now().toUtc();

  return McpAccessGrant(
    id: id,
    projectId: project,
    revisionId: revisionId,
    createdAt: now.subtract(const Duration(days: 3)),
    expiresAt:
        expired
            ? now.subtract(const Duration(days: 1))
            : now.add(const Duration(days: 1)),
    revokedAt: revoked ? now.subtract(const Duration(hours: 1)) : null,
  );
}

void main() {
  setUp(() {
    authSession.signIn('test-session');
  });

  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester, {
    bool enabled = true,
    bool canManage = true,
    List<McpApprovedRevision>? revisions,
    List<McpAccessGrant>? grants,
    Future<McpGrantCredential> Function(McpGrantCreationIntent)? onCreate,
    Future<void> Function(String)? onRevoke,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: McpGrantManagementPanel(
              projectId: projectId,
              integrationEnabled: enabled,
              canManage: canManage,
              revisions: revisions ?? [revision()],
              grants: grants ?? [grant()],
              expiryOptions: const [Duration(hours: 24), Duration(days: 7)],
              onCreate:
                  onCreate ??
                  (_) async => throw StateError('Unexpected create request'),
              onRevoke:
                  onRevoke ??
                  (_) async => throw StateError('Unexpected revoke request'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  final createButton = find.byKey(const ValueKey('mcp-create-grant'));

  Finder revokeButton(String id) => find.byKey(ValueKey('mcp-revoke-$id'));

  final confirmButton = find.byKey(const ValueKey('mcp-grant-confirm'));

  final cancelButton = find.byKey(const ValueKey('mcp-grant-cancel'));

  final secretFinder = find.byKey(const ValueKey('mcp-issued-credential'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> selectGrantOptions(WidgetTester tester) async {
    await tap(tester, find.byType(DropdownButtonFormField<String>));

    await tap(tester, find.text('Approved revision v5').last);

    await tap(tester, find.byType(DropdownButtonFormField<Duration>));

    await tap(tester, find.text('86400 seconds').last);
  }

  testWidgets('Disabled integration hides grant operations', (tester) async {
    await open(tester, enabled: false);

    expect(
      find.text('MCP grant management awaits backend integration.'),
      findsOneWidget,
    );

    expect(createButton, findsNothing);
    expect(revokeButton(grantId), findsNothing);
  });

  testWidgets('Permission denial hides grant data and operations', (
    tester,
  ) async {
    await open(tester, canManage: false);

    expect(find.text('Authorized project access is required.'), findsOneWidget);

    expect(createButton, findsNothing);
    expect(revokeButton(grantId), findsNothing);
    expect(find.text('Grant: $grantId'), findsNothing);
  });

  testWidgets('Unauthenticated user cannot manage grants', (tester) async {
    authSession.signOut();

    await open(tester);

    expect(find.text('Authorized project access is required.'), findsOneWidget);

    expect(createButton, findsNothing);
    expect(revokeButton(grantId), findsNothing);
  });

  testWidgets('No approved revision disables grant creation', (tester) async {
    await open(tester, revisions: []);

    expect(find.text('No approved revisions available.'), findsOneWidget);

    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);
  });

  testWidgets('Cross-project revisions and grants are excluded', (
    tester,
  ) async {
    await open(
      tester,
      revisions: [
        revision(),
        revision(project: otherId, id: otherId, version: 99),
      ],
      grants: [grant(), grant(id: otherId, project: otherId)],
    );

    expect(revokeButton(grantId), findsOneWidget);
    expect(revokeButton(otherId), findsNothing);

    await tap(tester, find.byType(DropdownButtonFormField<String>));

    expect(find.text('Approved revision v99'), findsNothing);

    expect(find.text('Approved revision v5'), findsWidgets);
  });

  testWidgets('Cancel creation does not invoke callback', (tester) async {
    var calls = 0;

    await open(
      tester,
      onCreate: (_) async {
        calls++;
        return McpGrantCredential('test-secret');
      },
    );

    await selectGrantOptions(tester);
    await tap(tester, createButton);

    expect(find.text('Create access grant?'), findsOneWidget);

    expect(calls, 0);

    await tap(tester, cancelButton);

    expect(calls, 0);

    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
  });

  testWidgets('Confirmed creation displays one-time credential', (
    tester,
  ) async {
    var calls = 0;

    final credential = McpGrantCredential('test-issued-secret');

    await open(
      tester,
      onCreate: (intent) async {
        calls++;

        expect(intent.projectId, projectId);
        expect(intent.revision.revisionId, revisionId);

        expect(intent.expiresAt.isAfter(DateTime.now()), isTrue);

        return credential;
      },
    );

    await selectGrantOptions(tester);
    await tap(tester, createButton);

    expect(calls, 0);

    await tap(tester, confirmButton);

    expect(calls, 1);
    expect(credential.available, isFalse);

    expect(
      tester.widget<SelectableText>(secretFinder).data,
      'test-issued-secret',
    );

    await tap(tester, find.byKey(const ValueKey('mcp-dismiss-credential')));

    expect(secretFinder, findsNothing);
    expect(createButton, findsNothing);

    expect(
      find.text('Reload verified grant data before another operation.'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel revocation does not invoke callback', (tester) async {
    var calls = 0;

    await open(
      tester,
      onRevoke: (_) async {
        calls++;
      },
    );

    await tap(tester, revokeButton(grantId));

    expect(find.text('Revoke access grant?'), findsOneWidget);

    expect(calls, 0);

    await tap(tester, cancelButton);

    expect(calls, 0);
  });

  testWidgets('Confirmed revocation sends selected grant ID once', (
    tester,
  ) async {
    final revoked = <String>[];

    await open(
      tester,
      onRevoke: (id) async {
        revoked.add(id);
      },
    );

    await tap(tester, revokeButton(grantId));

    expect(revoked, isEmpty);

    await tap(tester, confirmButton);

    expect(revoked, [grantId]);

    expect(
      find.text('Grant revocation confirmed. Reload grants.'),
      findsOneWidget,
    );

    expect(revokeButton(grantId), findsNothing);
  });

  testWidgets('Expired and revoked grant controls are disabled', (
    tester,
  ) async {
    await open(
      tester,
      grants: [
        grant(id: expiredId, expired: true),
        grant(id: revokedId, revoked: true),
      ],
    );

    expect(find.text('Status: Expired'), findsOneWidget);
    expect(find.text('Status: Revoked'), findsOneWidget);

    for (final id in [expiredId, revokedId]) {
      expect(tester.widget<OutlinedButton>(revokeButton(id)).onPressed, isNull);
    }
  });

  testWidgets('Logout during confirmation blocks revocation', (tester) async {
    var calls = 0;

    await open(
      tester,
      onRevoke: (_) async {
        calls++;
      },
    );

    await tap(tester, revokeButton(grantId));

    authSession.signOut();

    await tester.pump();

    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(calls, 0);

    expect(find.text('Authorized project access is required.'), findsOneWidget);

    expect(revokeButton(grantId), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed operation hides private diagnostics', (tester) async {
    await open(
      tester,
      onRevoke: (_) async {
        throw StateError('private-server-diagnostic');
      },
    );

    await tap(tester, revokeButton(grantId));
    await tap(tester, confirmButton);

    expect(
      find.text('Operation could not be confirmed. Reload grants.'),
      findsOneWidget,
    );

    expect(find.textContaining('private-server-diagnostic'), findsNothing);

    expect(revokeButton(grantId), findsNothing);
  });

  testWidgets('Logout clears displayed credential', (tester) async {
    await open(
      tester,
      onCreate: (_) async => McpGrantCredential('test-issued-secret'),
    );

    await selectGrantOptions(tester);
    await tap(tester, createButton);
    await tap(tester, confirmButton);

    expect(secretFinder, findsOneWidget);

    authSession.signOut();

    await tester.pumpAndSettle();

    expect(secretFinder, findsNothing);
    expect(createButton, findsNothing);
    expect(find.text('test-issued-secret'), findsNothing);
  });

  testWidgets('Credential arriving after logout is discarded', (tester) async {
    final pending = Completer<McpGrantCredential>();
    final credential = McpGrantCredential('test-late-secret');

    var calls = 0;

    await open(
      tester,
      onCreate: (_) {
        calls++;
        return pending.future;
      },
    );

    await selectGrantOptions(tester);
    await tap(tester, createButton);

    await tester.tap(confirmButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(calls, 1);

    authSession.signOut();
    await tester.pump();

    pending.complete(credential);

    await tester.pumpAndSettle();

    expect(credential.available, isFalse);
    expect(secretFinder, findsNothing);
    expect(find.text('test-late-secret'), findsNothing);
    expect(createButton, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
