import '../../../core/network/api_client.dart';

class AiIntelligenceRepository {
  const AiIntelligenceRepository(this.api);

  final ApiClient api;

  String _inputPath(String projectId) =>
      '/api/projects/$projectId/input-intelligence';

  String _requirementsPath(String projectId) =>
      '/api/projects/$projectId/requirements';

  String _blueprintsPath(String projectId) =>
      '/api/projects/$projectId/blueprints';

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Invalid server response');
    }
    return Map<String, dynamic>.from(value);
  }

  Future<List<Map<String, dynamic>>> extractRequirements({
    required String projectId,
    required String languageCode,
    required String inputText,
    required List<Map<String, dynamic>> evidence,
    required bool consentGranted,
  }) async {
    if (!consentGranted) {
      throw ArgumentError('AI processing consent is required');
    }

    if (inputText.trim().isEmpty) {
      throw ArgumentError('Requirement text is required');
    }

    if (evidence.isEmpty) {
      throw ArgumentError('Source evidence is required');
    }

    final response = _object(
      await api.post('${_inputPath(projectId)}/requirements/extract', {
        'languageCode': languageCode,
        'inputText': inputText,
        'evidence': evidence,
        'consentGranted': consentGranted,
      }),
    );

    final candidates = response['candidates'];

    if (response['contractVersion'] != '1.0' || candidates is! List) {
      throw const FormatException('Invalid AI candidate response');
    }

    return candidates.map(_object).toList();
  }

  Future<Map<String, dynamic>> submitReview({
    required String projectId,
    required String requirementId,
    required int expectedRevision,
    required String decision,
    String? editedTitle,
    String? editedDescription,
  }) async {
    if (requirementId.length > 100 ||
        !RegExp(r'^REQ-[A-Z0-9][A-Z0-9._-]*$').hasMatch(requirementId)) {
      throw ArgumentError('Invalid requirement ID');
    }

    if (expectedRevision < 1) {
      throw ArgumentError('Invalid requirement revision');
    }

    if (!['accept', 'edit', 'reject', 'defer'].contains(decision)) {
      throw ArgumentError('Unsupported review decision');
    }

    if (decision == 'edit') {
      if (editedTitle == null ||
          editedTitle.trim().isEmpty ||
          editedTitle.length > 200 ||
          editedDescription == null ||
          editedDescription.length > 4000) {
        throw ArgumentError('Valid edited title and description required');
      }
    } else if (editedTitle != null || editedDescription != null) {
      throw ArgumentError('Edit fields are only allowed for edit decisions');
    }

    final result = _object(
      await api.post(
        '/api/projects/$projectId/requirements/'
        '${Uri.encodeComponent(requirementId)}/review',
        {
          'expectedRevision': expectedRevision,
          'decision': decision,
          if (decision == 'edit') 'editedTitle': editedTitle,
          if (decision == 'edit') 'editedDescription': editedDescription,
        },
      ),
    );

    final expectedStatus = switch (decision) {
      'accept' => 'confirmed',
      'edit' => 'suggested',
      'reject' => 'rejected',
      'defer' => 'deferred',
      _ => throw StateError('Unsupported decision'),
    };

    if (result['requirementId'] != requirementId ||
        result['revision'] != expectedRevision + 1 ||
        result['status'] != expectedStatus) {
      throw const FormatException('Invalid server review receipt');
    }

    return result;
  }

  Future<Map<String, dynamic>> getReview(
    String projectId,
    String requirementId,
  ) async {
    return _object(
      await api.get(
        '${_requirementsPath(projectId)}/candidates/'
        '${Uri.encodeComponent(requirementId)}',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getClarifications(
    String projectId, {
    String? requirementId,
  }) async {
    if (requirementId != null) {
      final result = await api.get(
        '${_requirementsPath(projectId)}/candidates/'
        '${Uri.encodeComponent(requirementId)}/clarifications',
      );

      if (result is! List) {
        throw const FormatException('Invalid clarification response');
      }

      return result.map(_object).toList();
    }

    final candidates = await api.get(
      '${_requirementsPath(projectId)}/candidates?offset=0&limit=100',
    );

    if (candidates is! List) {
      throw const FormatException('Invalid requirement candidate response');
    }

    final clarifications = <Map<String, dynamic>>[];

    for (final candidate in candidates) {
      final row = _object(candidate);
      final id = row['id'];

      if (id is! String || id.isEmpty) {
        throw const FormatException('Invalid requirement candidate response');
      }

      clarifications.addAll(
        await getClarifications(projectId, requirementId: id),
      );
    }

    return clarifications;
  }

  Future<Map<String, dynamic>> createClarification({
    required String projectId,
    required String requirementId,
    required String question,
  }) async {
    final cleanQuestion = question.trim();

    if (requirementId.trim().isEmpty ||
        cleanQuestion.isEmpty ||
        cleanQuestion.length > 1500) {
      throw ArgumentError('A valid requirement and question are required');
    }

    return _object(
      await api.post(
        '${_requirementsPath(projectId)}/candidates/'
        '${Uri.encodeComponent(requirementId)}/clarifications',
        {'question': cleanQuestion},
      ),
    );
  }

  Future<Map<String, dynamic>> answerClarification({
    required String projectId,
    required String requirementId,
    required String questionId,
    required int expectedRevision,
    required String answer,
  }) async {
    final guid = RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
    );

    if (!guid.hasMatch(questionId) ||
        requirementId.trim().isEmpty ||
        expectedRevision < 1 ||
        answer.trim().isEmpty) {
      throw ArgumentError('Invalid clarification answer request');
    }

    return _object(
      await api.post(
        '${_requirementsPath(projectId)}/candidates/'
        '${Uri.encodeComponent(requirementId)}/clarifications/'
        '$questionId/answer',
        {'expectedRevision': expectedRevision, 'answer': answer.trim()},
      ),
    );
  }

  Future<Map<String, dynamic>> getReviewSyncStatus(String projectId) async {
    final candidatesValue = await api.get(
      '${_requirementsPath(projectId)}/candidates?offset=0&limit=100',
    );
    final blueprintVersion = _object(
      await api.get('${_blueprintsPath(projectId)}/current'),
    );

    if (candidatesValue is! List || blueprintVersion['blueprint'] is! Map) {
      throw const FormatException('Invalid review synchronization response');
    }

    final blueprint = _object(blueprintVersion['blueprint']);
    final blueprintRequirements = blueprint['requirements'];
    final revision = blueprint['revision'];

    if (blueprintRequirements is! List || revision is! int) {
      throw const FormatException('Invalid review synchronization response');
    }

    final byId = <String, Map<String, dynamic>>{};

    for (final requirement in blueprintRequirements) {
      final row = _object(requirement);
      final id = row['id'];

      if (id is! String || id.isEmpty) {
        throw const FormatException('Invalid Blueprint requirement response');
      }

      byId[id] = row;
    }

    final items = <Map<String, dynamic>>[];

    for (final candidateValue in candidatesValue) {
      final candidate = _object(candidateValue);
      final id = candidate['id'];
      final status = candidate['status']?.toString().toLowerCase();

      if (id is! String || id.isEmpty) {
        throw const FormatException('Invalid requirement candidate response');
      }

      if (status != 'confirmed' && status != '1') continue;

      final blueprintRequirement = byId[id];
      final blueprintStatus = blueprintRequirement?['status']?.toString();
      final synchronized = blueprintStatus?.toLowerCase() == 'confirmed';

      items.add({
        'requirementId': id,
        'reviewStatus': status,
        'blueprintStatus': blueprintStatus,
        'requiresRegeneration': !synchronized,
        if (!synchronized) 'problem': 'REQUIREMENT_MISSING_OR_STALE',
      });
    }

    return {
      'projectId': projectId,
      'blueprintRevision': revision,
      'existingRequirementsSynchronized': items.every(
        (item) => item['requiresRegeneration'] != true,
      ),
      'items': items,
    };
  }

  Map<String, dynamic> _draftResponse(dynamic value) {
    final response = _object(value);
    final token = response['concurrencyToken'];

    if (response['version'] is! int ||
        (response['version'] as int) < 1 ||
        token is! String ||
        !RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
        ).hasMatch(token) ||
        token == '00000000-0000-0000-0000-000000000000' ||
        response['draft'] is! Map) {
      throw const FormatException('Invalid project draft response');
    }

    return response;
  }

  Future<Map<String, dynamic>> generateBlueprint({
    required String projectId,
    required String? expectedConcurrencyToken,
    required List<String> confirmedRequirementIds,
  }) async {
    if (confirmedRequirementIds.isEmpty ||
        confirmedRequirementIds.length > 50 ||
        confirmedRequirementIds.toSet().length !=
            confirmedRequirementIds.length) {
      throw ArgumentError('Invalid confirmed requirement selection');
    }

    return _draftResponse(
      await api.post('${_blueprintsPath(projectId)}/generate', {
        'expectedConcurrencyToken': expectedConcurrencyToken,
        'requirementIds': confirmedRequirementIds,
      }),
    );
  }

  Future<Map<String, dynamic>> regenerateBlueprint({
    required String projectId,
    required String expectedConcurrencyToken,
    required int expectedRevision,
    required List<String> editableFeatureIds,
    required List<String> editableScreenIds,
    required List<String> editableComponentIds,
    Map<String, dynamic>? proposal,
  }) async {
    if (expectedRevision < 1) {
      throw ArgumentError('Invalid Blueprint revision');
    }

    return _draftResponse(
      await api.post('${_blueprintsPath(projectId)}/regenerate', {
        'expectedConcurrencyToken': expectedConcurrencyToken,
        'expectedRevision': expectedRevision,
        'editableFeatureIds': editableFeatureIds,
        'editableScreenIds': editableScreenIds,
        'editableComponentIds': editableComponentIds,
        if (proposal != null) 'proposal': proposal,
      }),
    );
  }
}
