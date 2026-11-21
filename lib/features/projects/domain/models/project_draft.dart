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

  CreateProjectRequest toCreateRequest() {
    return CreateProjectRequest(
      name: name,
      description: description,
    );
  }
}
