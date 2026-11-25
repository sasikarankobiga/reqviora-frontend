import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_invitation_widgets.dart';

void main() {
  test('Validates invitation email addresses', () {
    expect(isValidInvitationEmail('user@example.com'), isTrue);
    expect(isValidInvitationEmail(' user@example.com '), isTrue);
    expect(isValidInvitationEmail('invalid'), isFalse);
    expect(isValidInvitationEmail('user@'), isFalse);
    expect(isValidInvitationEmail('a b@example.com'), isFalse);
    expect(isValidInvitationEmail('a@@example.com'), isFalse);
  });

  testWidgets('Invitation send is disabled without integration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProjectInvitationDialog())),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('send-project-invitation')),
    );

    expect(button.onPressed, isNull);
    expect(
      find.text('Email invitation service is not configured.'),
      findsOneWidget,
    );
    expect(find.text('Invitation sent.'), findsNothing);
  });

  testWidgets('Invalid email never invokes invitation service', (tester) async {
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectInvitationDialog(
            onSend: (email, role) async {
              calls++;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('invitation-email')),
      'invalid-email',
    );

    await tester.tap(find.byKey(const ValueKey('send-project-invitation')));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Valid invitation invokes supplied callback', (tester) async {
    String? receivedEmail;
    ProjectMemberRole? receivedRole;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectInvitationDialog(
            onSend: (email, role) async {
              receivedEmail = email;
              receivedRole = role;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('invitation-email')),
      'user@example.com',
    );

    await tester.tap(find.byKey(const ValueKey('send-project-invitation')));
    await tester.pumpAndSettle();

    expect(receivedEmail, 'user@example.com');
    expect(receivedRole, ProjectMemberRole.viewer);
    expect(find.text('Invitation sent.'), findsOneWidget);
  });

  testWidgets('Failed invitation does not show fake success', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectInvitationDialog(
            onSend: (email, role) async {
              throw StateError('Test failure');
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('invitation-email')),
      'user@example.com',
    );

    await tester.tap(find.byKey(const ValueKey('send-project-invitation')));
    await tester.pumpAndSettle();

    expect(find.text('Invitation sent.'), findsNothing);
    expect(
      find.textContaining('Invitation could not be sent.'),
      findsOneWidget,
    );
  });

  testWidgets('Acceptance is disabled without integration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProjectInvitationAcceptancePage()),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('accept-project-invitation')),
    );

    expect(button.onPressed, isNull);
    expect(find.text('Invitation accepted.'), findsNothing);
  });

  testWidgets('Acceptance succeeds only after callback completion', (
    tester,
  ) async {
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectInvitationAcceptancePage(
          onAccept: () async {
            calls++;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('accept-project-invitation')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Invitation accepted.'), findsOneWidget);
  });

  testWidgets('Acceptance failure preserves error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectInvitationAcceptancePage(
          onAccept: () async {
            throw StateError('Invalid invitation');
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('accept-project-invitation')));
    await tester.pumpAndSettle();

    expect(find.text('Invitation accepted.'), findsNothing);
    expect(
      find.textContaining('Invitation could not be accepted.'),
      findsOneWidget,
    );
  });
}
