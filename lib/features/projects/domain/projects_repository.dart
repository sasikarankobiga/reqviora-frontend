import 'project.dart';

abstract class ProjectsRepository {
  Future<List<ProjectSummary>> list();
  Future<ProjectSummary> create({
    required String name,
    required String description,
    required String category,
    required List<String> designTargets,
  });
  Future<ProjectSummary> update({
    required String projectId,
    required String name,
    required String description,
    required String category,
  });
  Future<ProjectDraft> draft(String projectId);
  Future<ProjectDraft> saveIdentity(
    String projectId,
    Map<String, dynamic> values,
  );
}
