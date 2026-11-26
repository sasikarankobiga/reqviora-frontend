import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/workspace/domain/project_edit_policy.dart';

void main() {
  test('Approved owner retains revision history and export access', () {
    const policy = ProjectEditPolicy(
      role: ProjectMemberRole.owner,
      approved: true,
    );

    expect(policy.canAccessReviewHistory, isTrue);
    expect(policy.canEdit, isFalse);
    expect(policy.canApprove, isFalse);
    expect(policy.canEditStep(8), isFalse);
  });

  test('Non-owners cannot access owner-only revision operations', () {
    for (final role in [
      ProjectMemberRole.editor,
      ProjectMemberRole.viewer,
      null,
    ]) {
      final policy = ProjectEditPolicy(role: role, approved: true);

      expect(policy.canAccessReviewHistory, isFalse);
    }
  });

  test('Owner can edit all Builder steps and approve', () {
    const policy = ProjectEditPolicy(
      role: ProjectMemberRole.owner,
      approved: false,
    );

    for (var step = 1; step <= 8; step++) {
      expect(policy.canEditStep(step), isTrue);
    }

    expect(policy.canManageMembers, isTrue);
    expect(policy.canApprove, isTrue);
  });

  test('Editor cannot perform owner-only workflow actions', () {
    const policy = ProjectEditPolicy(
      role: ProjectMemberRole.editor,
      approved: false,
    );

    expect(policy.canEditStep(2), isTrue);
    expect(policy.canEditStep(6), isTrue);
    expect(policy.canEditStep(7), isFalse);
    expect(policy.canEditStep(8), isFalse);
    expect(policy.canManageMembers, isFalse);
    expect(policy.canApprove, isFalse);
  });

  test('Viewer cannot edit any Builder step', () {
    const policy = ProjectEditPolicy(
      role: ProjectMemberRole.viewer,
      approved: false,
    );

    expect(policy.canView, isTrue);

    for (var step = 1; step <= 8; step++) {
      expect(policy.canEditStep(step), isFalse);
    }

    expect(policy.canApprove, isFalse);
  });

  test('Approved draft is immutable for every role', () {
    for (final role in ProjectMemberRole.values) {
      final policy = ProjectEditPolicy(role: role, approved: true);

      expect(policy.canEdit, isFalse);
      expect(policy.canApprove, isFalse);
    }
  });

  test('Unknown membership and invalid steps are denied', () {
    const unknown = ProjectEditPolicy(role: null, approved: false);

    const owner = ProjectEditPolicy(
      role: ProjectMemberRole.owner,
      approved: false,
    );

    expect(unknown.canView, isFalse);
    expect(unknown.canEditStep(2), isFalse);
    expect(owner.canEditStep(0), isFalse);
    expect(owner.canEditStep(9), isFalse);
  });
}
