import '../data/project_members_repository.dart';

enum ProjectInvitationStatus {
  pending,
  accepted,
  rejected,
  revoked,
  expired;

  static ProjectInvitationStatus parse(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'pending' => pending,
      'accepted' => accepted,
      'rejected' => rejected,
      'revoked' => revoked,
      'expired' => expired,
      _ => throw const FormatException('Unsupported invitation status'),
    };
  }
}

class ProjectInvitation {
  const ProjectInvitation({
    required this.id,
    required this.projectId,
    required this.recipientEmail,
    required this.role,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.supersedesInvitationId,
  });

  final String id;
  final String projectId;
  final String recipientEmail;
  final ProjectMemberRole role;
  final ProjectInvitationStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? supersedesInvitationId;

  bool get canResend => status == ProjectInvitationStatus.pending;
  bool get canRevoke => status == ProjectInvitationStatus.pending;

  factory ProjectInvitation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final projectId = json['projectId'];
    final createdBy = json['createdBy'];
    final email = json['recipientEmail'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    final supersedes = json['supersedesInvitationId'];

    if (id is! String ||
        projectId is! String ||
        createdBy is! String ||
        !isProjectMemberGuid(id) ||
        !isProjectMemberGuid(projectId) ||
        !isProjectMemberGuid(createdBy) ||
        email is! String ||
        email.trim() != email ||
        email.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
        createdAt == null ||
        expiresAt == null ||
        !expiresAt.isAfter(createdAt) ||
        (supersedes != null &&
            (supersedes is! String || !isProjectMemberGuid(supersedes)))) {
      throw const FormatException('Invalid project invitation');
    }

    final role = ProjectMemberRole.parse(json['role']);
    if (role == ProjectMemberRole.owner) {
      throw const FormatException('Invalid invitation role');
    }

    return ProjectInvitation(
      id: id,
      projectId: projectId,
      recipientEmail: email,
      role: role,
      status: ProjectInvitationStatus.parse(json['status']),
      createdBy: createdBy,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
      supersedesInvitationId: supersedes as String?,
    );
  }
}

class AcceptedProjectMembership {
  const AcceptedProjectMembership({
    required this.projectId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String projectId;
  final String userId;
  final ProjectMemberRole role;
  final DateTime joinedAt;

  factory AcceptedProjectMembership.fromJson(Map<String, dynamic> json) {
    final projectId = json['projectId'];
    final userId = json['userId'];
    final joinedAt = DateTime.tryParse(json['joinedAt']?.toString() ?? '');
    final role = ProjectMemberRole.parse(json['role']);

    if (projectId is! String ||
        userId is! String ||
        !isProjectMemberGuid(projectId) ||
        !isProjectMemberGuid(userId) ||
        joinedAt == null ||
        role == ProjectMemberRole.owner) {
      throw const FormatException('Invalid accepted membership');
    }

    return AcceptedProjectMembership(
      projectId: projectId,
      userId: userId,
      role: role,
      joinedAt: joinedAt.toUtc(),
    );
  }
}
