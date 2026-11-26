import '../../../core/network/api_client.dart';
import 'dart:typed_data';
import '../domain/workspace.dart';
import '../domain/local_preview_blueprint.dart';

class WorkspaceRepository {
  const WorkspaceRepository(this.api);
  final ApiClient api;
  Future<Workspace> load(String projectId) async {
    final project = Map<String, dynamic>.from(
      await api.get('/api/projects/$projectId') as Map,
    );

    Map<String, dynamic> response;

    try {
      response = Map<String, dynamic>.from(
        await api.get('/api/projects/$projectId/drafts/current') as Map,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;

      response = {
        'projectId': projectId,
        'version': 0,
        'draft': <String, dynamic>{},
      };
    }

    final draft = Map<String, dynamic>.from(response['draft'] as Map? ?? {});

    // Support both existing root-level sections and a nested
    // sections object without discarding existing draft content.
    final sections = Map<String, dynamic>.from(
      draft['sections'] as Map? ?? draft,
    );

    final identity = Map<String, dynamic>.from(
      sections['identity'] as Map? ?? {},
    );

    final savedTargets = identity['designTargets'] ?? draft['designTargets'];

    final targets =
        savedTargets is List
            ? savedTargets.map((value) => value.toString()).toList()
            : [(project['primaryPlatform'] ?? 'web').toString()];

    return Workspace.fromJson({
      'projectId': projectId,
      'draftId': (response['id'] ?? projectId).toString(),
      'draftVersion': (response['version'] as num?)?.toInt() ?? 0,
      'projectName': (project['name'] ?? '').toString(),
      'designTargets': targets,
      'sections': sections,
    });
  }

  Future<int> save(
    String projectId,
    String section,
    int version,
    dynamic data,
  ) async {
    Map<String, dynamic> response;

    try {
      response = Map<String, dynamic>.from(
        await api.get('/api/projects/$projectId/drafts/current') as Map,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;

      response = {
        'projectId': projectId,
        'version': 0,
        'concurrencyToken': null,
        'draft': <String, dynamic>{},
      };
    }

    final latestVersion = (response['version'] as num?)?.toInt() ?? 0;

    if (latestVersion != version) {
      throw StateError(
        'The draft has changed. Reload the workspace and retry.',
      );
    }

    final updatedDraft = Map<String, dynamic>.from(
      response['draft'] as Map? ?? {},
    );

    // Preserve the draft's existing storage structure.
    if (updatedDraft['sections'] is Map) {
      final sections = Map<String, dynamic>.from(
        updatedDraft['sections'] as Map,
      );

      sections[section] = data;
      updatedDraft['sections'] = sections;
    } else {
      updatedDraft[section] = data;
    }

    final saved = Map<String, dynamic>.from(
      await api.put('/api/projects/$projectId/drafts/current', {
            'draft': updatedDraft,
            'expectedConcurrencyToken': response['concurrencyToken'],
          })
          as Map,
    );

    return (saved['version'] as num).toInt();
  }

  Future<Map<String, dynamic>> upload(
    String id,
    int version,
    String filename,
    Uint8List data,
  ) => api.uploadSource(id, version, filename, data);
  Future<void> addText(
    String id,
    int version,
    String text,
    String label,
  ) async {
    final cleanText = text.trim();
    final cleanLabel = label.trim();

    if (cleanText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Text source cannot be empty');
    }

    // Load the existing sources before appending a new one.
    final workspace = await load(id);

    if (workspace.version != version) {
      throw StateError('The workspace has changed. Reload and retry.');
    }

    final sources = workspace.items('sources');

    sources.add({
      'id': 'source-${DateTime.now().microsecondsSinceEpoch}',
      'type': 'text',
      'label': cleanLabel.isEmpty ? 'Project requirements' : cleanLabel,
      'text': cleanText,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    // Save through the current Backend Draft API.
    // Other sections and concurrency tokens are preserved
    // by the existing save() implementation.
    await save(id, 'sources', version, sources);
  }

  Future<void> decideCandidate(
    String projectId,
    String candidateId,
    int version,
    String decision, {
    String? editedName,
    String? editedDescription,
  }) async {
    if (!['accepted', 'rejected', 'deferred'].contains(decision)) {
      throw ArgumentError.value(decision, 'decision');
    }

    final workspace = await load(projectId);
    if (workspace.version != version) {
      throw StateError('Workspace changed. Reload and retry.');
    }

    final candidates = workspace.items('candidates');
    final index = candidates.indexWhere(
      (candidate) => candidate['id'].toString() == candidateId,
    );

    if (index < 0) {
      throw StateError('Suggestion not found.');
    }

    if (candidates[index]['status'] != 'suggested') {
      throw StateError('This suggestion has already been reviewed.');
    }

    final updated = <String, dynamic>{
      ...candidates[index],
      'status': decision,
      'reviewedAt': DateTime.now().toUtc().toIso8601String(),
    };

    if (editedName != null) {
      if (editedName.trim().isEmpty) {
        throw ArgumentError('Requirement name cannot be empty.');
      }
      updated['name'] = editedName.trim();
    }

    if (editedDescription != null) {
      updated['description'] = editedDescription.trim();
    }

    candidates[index] = updated;

    // Local Draft decision only.
    // This does not call the Backend approval boundary.
    await save(projectId, 'candidates', version, candidates);
  }

  Future<Map<String, dynamic>> analyze(String id, int version) async {
    final workspace = await load(id);

    if (workspace.version != version) {
      throw StateError('Workspace changed. Reload and retry.');
    }

    final sources = workspace.items('sources');
    final candidates = workspace.items('candidates');

    final existing =
        candidates
            .map(
              (candidate) =>
                  (candidate['description'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim(),
            )
            .toSet();

    var added = 0;
    final batchId = DateTime.now().microsecondsSinceEpoch;

    for (final source in sources) {
      final sourceText = (source['text'] ?? '').toString();

      // Deterministic local rules, not AI extraction.
      final sentences = sourceText.split(RegExp(r'[.!?\n]+'));

      for (final raw in sentences) {
        final sentence = raw.trim();
        if (sentence.length < 12 || sentence.length > 2000) continue;

        final lower = sentence.toLowerCase();

        final matchesRule =
            lower.contains('must ') ||
            lower.contains('should ') ||
            lower.contains('shall ') ||
            lower.contains('needs to ') ||
            lower.contains('வேண்டும்');

        if (!matchesRule || existing.contains(lower)) continue;

        existing.add(lower);

        candidates.add({
          'id': 'local-$batchId-$added',
          'name':
              sentence.length > 90
                  ? '${sentence.substring(0, 87)}...'
                  : sentence,
          'description': sentence,
          'sourceId': (source['id'] ?? '').toString(),
          'status': 'suggested',
          'origin': 'local-rule',
        });

        added++;

        if (added >= 30) break;
      }

      if (added >= 30) break;
    }

    if (added > 0) {
      await save(id, 'candidates', version, candidates);
    }

    return {'newSuggestions': added, 'analysisType': 'local-rule'};
  }

  Future<Map<String, dynamic>> compile(String id, int version) async {
    final workspace = await load(id);

    if (workspace.version != version) {
      throw StateError('Workspace changed. Reload and retry.');
    }

    final blueprint = buildLocalPreviewBlueprint(workspace);
    final savedVersion = await save(id, 'blueprint', version, blueprint);

    return {
      'draftVersion': savedVersion,
      'generationMode': 'local-template',
      'serverSaved': true,
      'approved': false,
    };
  }

  /// Saves a complete Backend Blueprint v1 document.
  ///
  /// Unlike local preview saving, this uses the official Blueprint API.
  /// It does not validate, approve or export the revision.
  Future<int> saveBackendBlueprint(
    String projectId,
    int expectedVersion,
    Map<String, dynamic> blueprint,
  ) async {
    if (blueprint['schemaVersion'] != '1.0.0' ||
        blueprint['projectId'] != projectId ||
        blueprint['lifecycle'] != 'draft' ||
        blueprint['blueprintId'] is! String ||
        !(blueprint['blueprintId'] as String).startsWith('BP-') ||
        blueprint['revision'] is! int ||
        (blueprint['revision'] as int) < 1) {
      throw ArgumentError('A matching Backend Blueprint v1 draft is required.');
    }

    for (final field in [
      'targetPlatforms',
      'requirements',
      'features',
      'screens',
      'components',
      'actions',
      'navigation',
    ]) {
      if (blueprint[field] is! List) {
        throw ArgumentError('Invalid Blueprint v1 field: $field');
      }
    }

    if ((blueprint['targetPlatforms'] as List).isEmpty) {
      throw ArgumentError('At least one target platform is required.');
    }

    Map<String, dynamic> current;

    try {
      current = Map<String, dynamic>.from(
        await api.get('/api/projects/$projectId/drafts/current') as Map,
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      current = {
        'version': 0,
        'concurrencyToken': null,
        'draft': <String, dynamic>{},
      };
    }

    final version = (current['version'] as num?)?.toInt() ?? 0;
    if (version != expectedVersion) {
      throw StateError(
        'Draft version changed. Reload before saving Blueprint v1.',
      );
    }

    final draft = Map<String, dynamic>.from(
      current['draft'] as Map? ?? {},
    );

    final saved = Map<String, dynamic>.from(
      await api.put('/api/projects/$projectId/blueprints/current', {
            'draft': draft,
            'blueprint': blueprint,
            'expectedConcurrencyToken': current['concurrencyToken'],
          })
          as Map,
    );

    final savedVersion = saved['version'];
    if (savedVersion is! num) {
      throw StateError('Backend returned no saved draft version.');
    }

    return savedVersion.toInt();
  }
  Future<Map<String, dynamic>> validate(String id) async {
    final current = Map<String, dynamic>.from(
      await api.get('/api/projects/$id/drafts/current') as Map,
    );

    final token = current['concurrencyToken'];

    if (token == null) {
      throw StateError('Save the project draft before validating.');
    }

    return Map<String, dynamic>.from(
      await api.post('/api/projects/$id/blueprints/validate', {
            'expectedConcurrencyToken': token,
          })
          as Map,
    );
  }

  Future<Map<String, dynamic>> approveValidatedDraft(
    String projectId,
    int expectedVersion,
    String validationRunId,
  ) async {
    final current = Map<String, dynamic>.from(
      await api.get('/api/projects/$projectId/drafts/current') as Map,
    );

    final latestVersion = (current['version'] as num?)?.toInt();
    if (latestVersion != expectedVersion) {
      throw StateError(
        'The draft changed after validation. Reload and validate again.',
      );
    }

    final token = current['concurrencyToken'];
    if (token == null || token.toString().isEmpty) {
      throw StateError('A saved draft concurrency token is required.');
    }

    if (validationRunId.trim().isEmpty) {
      throw ArgumentError.value(
        validationRunId,
        'validationRunId',
        'Validation run ID is required',
      );
    }

    return Map<String, dynamic>.from(
      await api.post('/api/projects/$projectId/approvals', {
        'expectedConcurrencyToken': token,
        'validationRunId': validationRunId,
      }) as Map,
    );
  }
  Future<Map<String, dynamic>> createOfficialExport(
    String projectId,
    String approvedRevisionId,
  ) async {
    if (approvedRevisionId.trim().isEmpty) {
      throw ArgumentError.value(
        approvedRevisionId,
        'approvedRevisionId',
        'An approved revision ID is required.',
      );
    }

    return Map<String, dynamic>.from(
      await api.post(
        '/api/projects/$projectId/exports/from-revision/$approvedRevisionId',
        <String, dynamic>{},
      ) as Map,
    );
  }

  Future<List<int>> downloadOfficialExport(
    String projectId,
    String exportId,
  ) async {
    if (exportId.trim().isEmpty) {
      throw ArgumentError.value(
        exportId,
        'exportId',
        'An official export ID is required.',
      );
    }

    return api.getBytes(
      '/api/projects/$projectId/exports/$exportId/download',
    );
  }

  Future<List<int>> exportDraft(String id) async {
    throw UnsupportedError(
      'Draft ZIP export is not supported by the current Backend. '
      'An approved revision and export record are required.',
    );
  }
}
