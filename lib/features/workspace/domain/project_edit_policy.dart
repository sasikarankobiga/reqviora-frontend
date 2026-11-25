import '../../projects/data/project_members_repository.dart';

/// Frontend editing hints only.
/// Backend authorization remains the security authority.
class ProjectEditPolicy {
  const ProjectEditPolicy({required this.role, required this.approved});

  final ProjectMemberRole? role;
  final bool approved;

  bool get canView => role != null;

  // Approved owners may still inspect and export immutable revisions.
  bool get canAccessReviewHistory => role == ProjectMemberRole.owner;

  bool get canEdit =>
      !approved &&
      (role == ProjectMemberRole.owner || role == ProjectMemberRole.editor);

  bool get canManageMembers => role == ProjectMemberRole.owner;

  bool get canApprove => !approved && role == ProjectMemberRole.owner;

  bool canEditStep(int step) {
    if (!canEdit || step < 1 || step > 8) {
      return false;
    }

    // Server workflow generation and approval are
    // deliberately restricted to owners in this UI.
    if (step >= 7) {
      return role == ProjectMemberRole.owner;
    }

    return true;
  }
}
