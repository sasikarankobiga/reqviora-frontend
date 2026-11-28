import '../../../core/network/api_client.dart';
import '../domain/project_invitation.dart';
import 'project_members_repository.dart';

class ProjectInvitationsRepository {
  const ProjectInvitationsRepository(this.api);

  final ApiClient api;

  String _projectPath(String projectId, [String? invitationId]) {
    if (!isProjectMemberGuid(projectId)) {
      throw ArgumentError('Invalid project ID');
    }
    if (invitationId != null && !isProjectMemberGuid(invitationId)) {
      throw ArgumentError('Invalid invitation ID');
    }
    return '/api/projects/$projectId/invitations'
        '${invitationId == null ? '' : '/$invitationId'}';
  }

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid invitation response');
    }
    return Map<String, dynamic>.from(value);
  }

  ProjectInvitation _invitation(Object? value, String projectId) {
    final invitation = ProjectInvitation.fromJson(_object(value));
    if (invitation.projectId.toLowerCase() != projectId.toLowerCase()) {
      throw const FormatException('Invitation belongs to another project');
    }
    return invitation;
  }

  Future<List<ProjectInvitation>> list(String projectId) async {
    final result = await api.get(_projectPath(projectId));
    if (result is! List) {
      throw const FormatException('Invalid invitation list');
    }
    final invitations = result
        .map((value) => _invitation(value, projectId))
        .toList(growable: false);
    if (invitations.map((item) => item.id.toLowerCase()).toSet().length !=
        invitations.length) {
      throw const FormatException('Duplicate invitation response');
    }
    return List.unmodifiable(invitations);
  }

  Future<ProjectInvitation> create({
    required String projectId,
    required String recipientEmail,
    required ProjectMemberRole role,
  }) async {
    final email = recipientEmail.trim();
    if (email.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ArgumentError('Invalid recipient email');
    }
    if (role == ProjectMemberRole.owner) {
      throw ArgumentError('Invalid invitation role');
    }
    final result = await api.post(_projectPath(projectId), {
      'recipientEmail': email,
      'role': role.apiValue,
    });
    return _invitation(result, projectId);
  }

  Future<ProjectInvitation> resend({
    required String projectId,
    required String invitationId,
  }) async {
    final result = await api.post(
      '${_projectPath(projectId, invitationId)}/resend',
      const {},
    );
    return _invitation(result, projectId);
  }

  Future<ProjectInvitation> revoke({
    required String projectId,
    required String invitationId,
  }) async {
    final result = await api.post(
      '${_projectPath(projectId, invitationId)}/revoke',
      const {},
    );
    return _invitation(result, projectId);
  }

  Future<AcceptedProjectMembership> accept(String token) async {
    final result = await _respond('accept', token);
    return AcceptedProjectMembership.fromJson(result);
  }

  Future<ProjectInvitation> reject(String token) async {
    final result = await _respond('reject', token);
    return ProjectInvitation.fromJson(result);
  }

  Future<Map<String, dynamic>> _respond(String action, String token) async {
    if (token.trim() != token || token.length < 32 || token.length > 512) {
      throw ArgumentError('Invalid invitation token');
    }
    return _object(
      await api.post('/api/project-invitations/$action', {'token': token}),
    );
  }
}
