// REQVIORA TASK 005B — Developer B-owned UI integration boundary.
// Backend does NOT provide phase or completion state.

import '../../domain/models/project.dart';
import '../view_data/project_hub_view_data.dart';

/// Intermediate data that retains unknown presentation metadata.
///
/// Do not present phase/completion as backend-confirmed values.
final class ProjectHubDisplayDraft {
  const ProjectHubDisplayDraft({
    required this.id,
    required this.name,
    required this.description,
    required this.lastActivityAt,
  });

  final ProjectId id;
  final String name;
  final String description;
  final DateTime lastActivityAt;

  HubProjectPhase? get phase => null;
  bool? get isCompleted => null;

  String get progressLabel => 'Progress not confirmed';

  /// Metadata must be explicitly approved by the integration caller.
  ProjectHubViewData toViewData({
    required HubProjectPhase approvedDisplayPhase,
    required bool approvedCompletionStatus,
    String? updatedLabel,
  }) {
    return ProjectHubViewData(
      id: id.value,
      name: name,
      description: description,
      updatedLabel: updatedLabel ?? progressLabel,
      phase: approvedDisplayPhase,
      isCompleted: approvedCompletionStatus,
    );
  }
}

abstract final class ProjectHubAdapter {
  static ProjectHubDisplayDraft fromProject(Project project) {
    return ProjectHubDisplayDraft(
      id: project.id,
      name: project.name,
      description: project.description,
      lastActivityAt: project.lastModifiedAt ?? project.createdAt,
    );
  }

  static List<ProjectHubDisplayDraft> fromProjects(
    List<Project> projects,
  ) {
    return List<ProjectHubDisplayDraft>.unmodifiable(
      projects.map(fromProject),
    );
  }

  /// The existing UI requires a display phase and completion bool.
  /// These cannot be inferred from ProjectResponseDto.
  static ProjectId parseCallbackId(String value) {
    return ProjectId.parse(value);
  }
}
