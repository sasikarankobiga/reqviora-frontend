import '../models/project.dart';

/// Repository contract for project operations.
///
/// This interface does not decide whether data comes from
/// a backend API or a mock implementation.
abstract interface class ProjectRepository {
  Future<List<Project>> listProjects();

  Future<Project> getProject(ProjectId id);

  Future<Project> createProject({
    required String name,
    required String description,
  });

  /// Full update of the currently supported backend fields.
  /// This is not a PATCH operation.
  Future<Project> updateProject(
    ProjectId id, {
    required String name,
    required String description,
  });
}

final class ProjectNotFoundException implements Exception {
  const ProjectNotFoundException(this.id);

  final ProjectId id;

  @override
  String toString() => 'Project not found: ${id.value}';
}
