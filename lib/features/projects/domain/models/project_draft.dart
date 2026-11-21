import 'project_requests.dart';

/// One frontend draft shared across the project workflow.
/// This is not a backend response or a persistence service.
class ProjectDraft {
  ProjectDraft({
    required String name,
    required String description,
  })  : name = name.trim(),
        description = description.trim();

  factory ProjectDraft.fromRequest(
    CreateProjectRequest request,
  ) {
    return ProjectDraft(
      name: request.name,
      description: request.description,
    );
  }

  String name;
  String description;

  // Frontend-only draft fields. Not part of the current API contract.
  String targetAudience = '';
  String primaryUserGoal = '';

  void update({
    required String name,
    required String description,
  }) {
    final validated = CreateProjectRequest(
      name: name,
      description: description,
    );

    this.name = validated.name;
    this.description = validated.description;
  }

  void updateAudience({
    required String targetAudience,
    required String primaryUserGoal,
  }) {
    final audience = targetAudience.trim();
    final goal = primaryUserGoal.trim();

    if (audience.length > 200) {
      throw ArgumentError('Target audience exceeds 200 characters');
    }
    if (goal.length > 1000) {
      throw ArgumentError('Primary user goal exceeds 1000 characters');
    }

    this.targetAudience = audience;
    this.primaryUserGoal = goal;
  }

  CreateProjectRequest toCreateRequest() {
    return CreateProjectRequest(
      name: name,
      description: description,
    );
  }
}
