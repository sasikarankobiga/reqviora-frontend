class ProjectSummary {
  const ProjectSummary({required this.id, required this.name, required this.status,
    required this.updatedAt});
  final String id;
  final String name;
  final String status;
  final DateTime updatedAt;
  factory ProjectSummary.fromJson(Map<String, dynamic> data) => ProjectSummary(
    id: data['projectId'] as String,
    name: data['name'] as String,
    status: data['status'] as String? ?? 'active',
    updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class ProjectDraft {
  const ProjectDraft({required this.projectId, required this.version,
    required this.name, required this.description, required this.category,
    required this.targets, required this.identity});
  final String projectId;
  final int version;
  final String name;
  final String description;
  final String category;
  final List<String> targets;
  final Map<String, dynamic> identity;
  factory ProjectDraft.fromJson(Map<String, dynamic> json) {
    final project = Map<String, dynamic>.from(json['project'] as Map);
    return ProjectDraft(
      projectId: json['projectId'] as String, version: json['draftVersion'] as int,
      name: project['name'] as String? ?? '',
      description: project['description'] as String? ?? '',
      category: project['category'] as String? ?? '',
      targets: List<String>.from(project['designTargets'] as List? ?? []),
      identity: Map<String, dynamic>.from(project['identity'] as Map? ?? {}),
    );
  }
  String field(String key) => identity[key] as String? ?? '';
}
