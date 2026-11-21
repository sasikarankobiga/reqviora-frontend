
class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final String industry;
  final String targetAudience;
  final String projectType;
  final String primaryPlatform;
  final String technologyPreferences;
  final String constraints;
  final String integrations;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.createdAt,
    this.lastModifiedAt,
    this.industry = '',
    this.targetAudience = '',
    this.projectType = '',
    this.primaryPlatform = 'web',
    this.technologyPreferences = '',
    this.constraints = '',
    this.integrations = '',
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      ownerId: json['ownerId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: json['lastModifiedAt'] == null
          ? null
          : DateTime.parse(json['lastModifiedAt'] as String),
      industry: (json['industry'] as String?) ?? '',
      targetAudience: (json['targetAudience'] as String?) ?? '',
      projectType: (json['projectType'] as String?) ?? '',
      primaryPlatform: (json['primaryPlatform'] as String?) ?? 'web',
      technologyPreferences:
          (json['technologyPreferences'] as String?) ?? '',
      constraints: (json['constraints'] as String?) ?? '',
      integrations: (json['integrations'] as String?) ?? '',
    );
  }
}
