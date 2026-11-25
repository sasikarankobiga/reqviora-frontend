import '../../../core/network/api_client.dart';

enum ProjectMemberRole {
  owner,
  editor,
  viewer;

  String get apiValue => switch (this) {
    owner => 'Owner',
    editor => 'Editor',
    viewer => 'Viewer',
  };

  static ProjectMemberRole parse(dynamic value) {
    return switch (value?.toString().toLowerCase()) {
      'owner' => owner,
      'editor' => editor,
      'viewer' => viewer,
      _ => throw const FormatException('Unsupported project member role'),
    };
  }
}

bool isProjectMemberGuid(String value) =>
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value) &&
    value != '00000000-0000-0000-0000-000000000000';

class ProjectMember {
  const ProjectMember({
    required this.userId,
    required this.role,
    this.joinedAtUtc,
  });

  final String userId;
  final ProjectMemberRole role;
  final DateTime? joinedAtUtc;

  bool get isOwner => role == ProjectMemberRole.owner;

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    final id = json['userId'];

    if (id is! String || !isProjectMemberGuid(id)) {
      throw const FormatException('Invalid project member ID');
    }

    final role = ProjectMemberRole.parse(json['role']);
    final rawDate = json['joinedAtUtc'];

    final date = rawDate == null ? null : DateTime.tryParse(rawDate.toString());

    if (rawDate != null && date == null) {
      throw const FormatException('Invalid member join date');
    }

    return ProjectMember(userId: id, role: role, joinedAtUtc: date);
  }
}

class ProjectMembersRepository {
  const ProjectMembersRepository(this.api);

  final ApiClient api;

  String _path(String projectId, [String? memberId]) {
    if (!isProjectMemberGuid(projectId)) {
      throw ArgumentError('Invalid project ID');
    }

    if (memberId != null && !isProjectMemberGuid(memberId)) {
      throw ArgumentError('Invalid member user ID');
    }

    return '/api/projects/$projectId/members'
        '${memberId == null ? '' : '/$memberId'}';
  }

  Future<List<ProjectMember>> getMembers(String projectId) async {
    final result = await api.get(_path(projectId));

    if (result is! List) {
      throw const FormatException('Invalid member list');
    }

    final members =
        result.map((value) {
          if (value is! Map) {
            throw const FormatException('Invalid project member');
          }

          return ProjectMember.fromJson(Map<String, dynamic>.from(value));
        }).toList();

    final uniqueIds =
        members.map((member) => member.userId.toLowerCase()).toSet();

    if (uniqueIds.length != members.length ||
        members.where((member) => member.isOwner).length != 1) {
      throw const FormatException('Invalid project membership list');
    }

    return List.unmodifiable(members);
  }

  Future<ProjectMember> setMemberRole({
    required String projectId,
    required String memberUserId,
    required ProjectMemberRole role,
  }) async {
    if (role == ProjectMemberRole.owner) {
      throw ArgumentError(
        'Owner role cannot be assigned through member management',
      );
    }

    final result = await api.put(_path(projectId, memberUserId), {
      'role': role.apiValue,
    });

    if (result is! Map) {
      throw const FormatException('Invalid member response');
    }

    final member = ProjectMember.fromJson(Map<String, dynamic>.from(result));

    if (member.userId.toLowerCase() != memberUserId.toLowerCase() ||
        member.role != role) {
      throw const FormatException('Unexpected member response');
    }

    return member;
  }

  Future<void> removeMember({
    required String projectId,
    required String memberUserId,
  }) async {
    await api.delete(_path(projectId, memberUserId));
  }
}
