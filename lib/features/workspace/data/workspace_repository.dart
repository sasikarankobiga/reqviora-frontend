import '../../../core/network/api_client.dart';
import 'dart:typed_data';
import '../domain/workspace.dart';

class WorkspaceRepository {
  const WorkspaceRepository(this.api);
  final ApiClient api;
  Future<Workspace> load(String projectId) async => Workspace.fromJson(
      Map<String, dynamic>.from(await api.get('/api/v1/projects/$projectId/workspace') as Map));
  Future<int> save(String projectId, String section, int version, dynamic data) async {
    final value = await api.put('/api/v1/projects/$projectId/workspace/$section',
      {'expectedVersion': version, 'data': data});
    return (value as Map)['draftVersion'] as int;
  }
  Future<Map<String, dynamic>> upload(String id, int version, String filename, Uint8List data) =>
    api.uploadSource(id, version, filename, data);
  Future<void> addText(String id, int version, String text, String label) async {
    await api.post('/api/v1/projects/$id/sources/text',
      {'expectedVersion': version, 'text': text, 'label': label});
  }
  Future<void> decideCandidate(String projectId, String candidateId, int version, String decision,
      {String? editedName, String? editedDescription}) async {
    await api.post('/api/v1/projects/$projectId/candidates/$candidateId/decision',
      {'expectedVersion': version, 'decision': decision,
        if (editedName != null) 'editedName': editedName,
        if (editedDescription != null) 'editedDescription': editedDescription});
  }
  Future<Map<String, dynamic>> analyze(String id, int version) async =>
    Map<String, dynamic>.from(await api.post('/api/v1/projects/$id/analysis/local',
      {'expectedVersion': version, 'data': <String, dynamic>{}}) as Map);
  Future<Map<String, dynamic>> compile(String id, int version) async =>
    Map<String, dynamic>.from(await api.post('/api/v1/projects/$id/blueprint/compile',
      {'expectedVersion': version, 'data': <String, dynamic>{}}) as Map);
  Future<Map<String, dynamic>> validate(String id) async =>
    Map<String, dynamic>.from(await api.get('/api/v1/projects/$id/validation-runs/current') as Map);
  Future<List<int>> exportDraft(String id) => api.getBytes('/api/v1/projects/$id/exports/draft/download');
}
