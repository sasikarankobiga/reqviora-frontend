import '../../../core/network/api_client.dart';
import '../domain/project.dart';
import '../domain/projects_repository.dart';

class HttpProjectsRepository implements ProjectsRepository {
  HttpProjectsRepository(this.api);
  final ApiClient api;
  @override Future<List<ProjectSummary>> list() async {
    final data = await api.get('/api/v1/projects') as List;
    return data.map((entry) => ProjectSummary.fromJson(Map<String, dynamic>.from(entry as Map))).toList();
  }
  @override Future<ProjectSummary> create({required String name, required String description,
    required String category, required List<String> designTargets}) async {
    final key = 'reqv-${DateTime.now().microsecondsSinceEpoch}';
    final data = await api.post('/api/v1/projects', {
      'name': name, 'description': description, 'category': category,
      'designTargets': designTargets,
    }, key: key);
    return ProjectSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }
  @override Future<ProjectDraft> draft(String projectId) async {
    final data = await api.get('/api/v1/projects/$projectId/draft');
    return ProjectDraft.fromJson(Map<String, dynamic>.from(data as Map));
  }
  @override Future<ProjectDraft> saveIdentity(String projectId, Map<String, dynamic> values) async {
    final data = await api.put('/api/v1/projects/$projectId/builder/steps/1', values);
    return ProjectDraft.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
