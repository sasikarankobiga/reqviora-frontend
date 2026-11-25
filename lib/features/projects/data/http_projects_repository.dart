import '../../../core/network/api_client.dart';
import '../domain/project.dart';
import '../domain/projects_repository.dart';

class HttpProjectsRepository implements ProjectsRepository {
  HttpProjectsRepository(this.api);

  final ApiClient api;

  @override
  Future<List<ProjectSummary>> list() async {
    final data = await api.get('/api/projects') as List;

    return data
        .map(
          (entry) =>
              ProjectSummary.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
  }

  @override
  Future<ProjectSummary> create({
    required String name,
    required String description,
    required String category,
    required List<String> designTargets,
  }) async {
    final primaryPlatform =
        designTargets.contains('web')
            ? 'web'
            : designTargets.isNotEmpty
            ? designTargets.first
            : 'web';

    final key = 'reqv-${DateTime.now().microsecondsSinceEpoch}';

    final data = await api.post('/api/projects', {
      'name': name,
      'description': description,
      'industry': category,
      'primaryPlatform': primaryPlatform,
    }, key: key);

    return ProjectSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<ProjectDraft> draft(String projectId) async {
    // Get the project details separately because the Draft API
    // does not include the complete project record.
    final project = Map<String, dynamic>.from(
      await api.get('/api/projects/$projectId') as Map,
    );

    Map<String, dynamic> response;

    try {
      response = Map<String, dynamic>.from(
        await api.get('/api/projects/$projectId/drafts/current') as Map,
      );
    } on ApiException catch (e) {
      // A newly created project may not have a draft yet.
      // Do not create a draft until the user saves Step 01.
      if (e.statusCode != 404) rethrow;

      response = {
        'projectId': projectId,
        'version': 0,
        'draft': <String, dynamic>{},
        'concurrencyToken': null,
      };
    }

    return ProjectDraft.fromJson({
      ...response,
      'projectId': projectId,
      'project': project,
    });
  }

  @override
  Future<ProjectDraft> saveIdentity(
    String projectId,
    Map<String, dynamic> values,
  ) async {
    // Load current draft and its concurrency token.
    final current = await draft(projectId);

    final expectedVersion = values['expectedVersion'];

    // Prevent replacing a newer draft with an older editor state.
    if (expectedVersion is! int || expectedVersion != current.version) {
      throw StateError(
        'The project draft has changed. Reload Step 01 and retry.',
      );
    }

    // Preserve all other draft sections.
    final updatedDraft = <String, dynamic>{...current.rawDraft};

    final identity = <String, dynamic>{...current.identity, ...values};

    // This is UI metadata, not an identity field.
    identity.remove('expectedVersion');

    updatedDraft['identity'] = identity;

    final response = Map<String, dynamic>.from(
      await api.put('/api/projects/$projectId/drafts/current', {
            'draft': updatedDraft,
            'expectedConcurrencyToken': current.concurrencyToken,
          })
          as Map,
    );

    // Retain the project metadata while parsing the saved draft.
    final project = <String, dynamic>{
      'name': current.name,
      'description': current.description,
      'industry': current.category,
      'primaryPlatform':
          current.targets.isNotEmpty ? current.targets.first : 'web',
    };

    return ProjectDraft.fromJson({
      ...response,
      'projectId': projectId,
      'project': project,
    });
  }
}
