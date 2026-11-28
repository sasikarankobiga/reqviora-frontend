import '../../../core/network/api_client.dart';
import '../domain/project.dart';
import '../domain/projects_repository.dart';

bool _jsonEqual(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  if (left is List && right is List) {
    return left.length == right.length &&
        Iterable.generate(
          left.length,
        ).every((index) => _jsonEqual(left[index], right[index]));
  }
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _jsonEqual(left[key], right[key]),
        );
  }
  return false;
}

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
    final expectedIdentity = values['_expectedIdentity'];

    // Prevent replacing a newer draft with an older editor state.
    if (expectedVersion is! int ||
        (expectedVersion != current.version &&
            !_jsonEqual(expectedIdentity, current.identity))) {
      throw StateError(
        'Step 01 changed in another save. Your edits were not overwritten; '
        'reload and reconcile them before retrying.',
      );
    }

    // Preserve all other draft sections.
    final updatedDraft = <String, dynamic>{...current.rawDraft};

    // Merge existing identity fields with the submitted values.
    final identity = <String, dynamic>{...current.identity, ...values};

    // This is UI metadata, not an identity field.
    identity.remove('expectedVersion');
    identity.remove('_expectedIdentity');

    if (updatedDraft['sections'] is Map) {
      final sections = Map<String, dynamic>.from(
        updatedDraft['sections'] as Map,
      );

      final existingIdentity = sections['identity'];

      // Preserve existing nested identity fields.
      final mergedIdentity = <String, dynamic>{
        ...current.identity,
        if (existingIdentity is Map)
          ...Map<String, dynamic>.from(existingIdentity),
        ...values,
      };

      // Never persist UI-only version metadata.
      mergedIdentity.remove('expectedVersion');
      mergedIdentity.remove('_expectedIdentity');

      sections['identity'] = mergedIdentity;

      updatedDraft['sections'] = sections;
    } else {
      // Support existing flat draft structures.
      updatedDraft['identity'] = identity;
    }

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
