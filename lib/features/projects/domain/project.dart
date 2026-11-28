class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.updatedAt,
    this.category = '',
  });

  final String id;
  final String name;
  final String status;
  final DateTime updatedAt;
  final String category;

  factory ProjectSummary.fromJson(Map<String, dynamic> data) {
    final rawId = data['id'] ?? data['projectId'];

    if (rawId == null || rawId.toString().isEmpty) {
      throw const FormatException('Project ID is missing');
    }

    final rawDate =
        data['lastModifiedAt'] ?? data['createdAt'] ?? data['updatedAt'];

    return ProjectSummary(
      id: rawId.toString(),
      name: (data['name'] ?? '').toString(),
      status: (data['status'] ?? 'active').toString(),
      category: (data['industry'] ?? data['category'] ?? '').toString(),
      updatedAt: DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

List<ProjectSummary> filterProjectSummaries(
  Iterable<ProjectSummary> projects, {
  String query = '',
  String? category,
}) {
  final needle = query.trim().toLowerCase();
  final selectedCategory = category?.trim();
  return projects
      .where(
        (project) =>
            (needle.isEmpty ||
                project.name.toLowerCase().contains(needle) ||
                project.category.toLowerCase().contains(needle)) &&
            (selectedCategory == null ||
                selectedCategory.isEmpty ||
                project.category == selectedCategory),
      )
      .toList(growable: false);
}

class ProjectDraft {
  const ProjectDraft({
    required this.projectId,
    required this.version,
    required this.name,
    required this.description,
    required this.category,
    required this.targets,
    required this.identity,
    this.concurrencyToken,
    this.rawDraft = const {},
  });

  final String projectId;
  final int version;
  final String name;
  final String description;
  final String category;
  final List<String> targets;
  final Map<String, dynamic> identity;

  final String? concurrencyToken;
  final Map<String, dynamic> rawDraft;

  factory ProjectDraft.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('draftVersion')) {
      final project = Map<String, dynamic>.from(json['project'] as Map);

      return ProjectDraft(
        projectId: json['projectId'].toString(),
        version: (json['draftVersion'] as num).toInt(),
        name: (project['name'] ?? '').toString(),
        description: (project['description'] ?? '').toString(),
        category: (project['category'] ?? '').toString(),
        targets: List<String>.from(project['designTargets'] as List? ?? []),
        identity: Map<String, dynamic>.from(project['identity'] as Map? ?? {}),
        concurrencyToken: json['concurrencyToken']?.toString(),
        rawDraft: Map<String, dynamic>.from(json['draft'] as Map? ?? {}),
      );
    }

    final raw = Map<String, dynamic>.from(json['draft'] as Map? ?? {});

    final sections = raw['sections'];

    final identity = Map<String, dynamic>.from(
      sections is Map
          ? (sections['identity'] as Map? ?? {})
          : (raw['identity'] as Map? ?? {}),
    );

    final project = Map<String, dynamic>.from(json['project'] as Map? ?? {});

    final primaryPlatform = (project['primaryPlatform'] ?? 'web').toString();

    final savedTargets = identity['designTargets'] ?? raw['designTargets'];

    return ProjectDraft(
      projectId: json['projectId'].toString(),
      version: (json['version'] as num?)?.toInt() ?? 0,
      name: (identity['name'] ?? project['name'] ?? '').toString(),
      description:
          (identity['description'] ?? project['description'] ?? '').toString(),
      category: (identity['category'] ?? project['industry'] ?? '').toString(),
      targets:
          savedTargets is List
              ? savedTargets.map((value) => value.toString()).toList()
              : [primaryPlatform],
      identity: identity,
      concurrencyToken: json['concurrencyToken']?.toString(),
      rawDraft: raw,
    );
  }

  String field(String key) => identity[key]?.toString() ?? '';
}
