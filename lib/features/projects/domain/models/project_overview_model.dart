
class ProjectOverviewModel {
  final String projectId;
  final String name;
  final String description;
  final String ownerId;
  final String? workspaceId;
  final int? currentDraftVersion;
  final String? draftConcurrencyToken;
  final String? approvedRevisionId;
  final int requirementCount;
  final int featureCount;
  final int screenCount;
  final int navigationCount;

  const ProjectOverviewModel({
    required this.projectId,
    required this.name,
    required this.description,
    required this.ownerId,
    this.workspaceId,
    this.currentDraftVersion,
    this.draftConcurrencyToken,
    this.approvedRevisionId,
    required this.requirementCount,
    required this.featureCount,
    required this.screenCount,
    required this.navigationCount,
  });

  factory ProjectOverviewModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProjectOverviewModel(
      projectId: json['projectId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      ownerId: json['ownerId'] as String,
      workspaceId: json['workspaceId'] as String?,
      currentDraftVersion: json['currentDraftVersion'] as int?,
      draftConcurrencyToken:
          json['draftConcurrencyToken'] as String?,
      approvedRevisionId: json['approvedRevisionId'] as String?,
      requirementCount: json['requirementCount'] as int,
      featureCount: json['featureCount'] as int,
      screenCount: json['screenCount'] as int,
      navigationCount: json['navigationCount'] as int,
    );
  }
}
