import '../../../core/network/api_client.dart';

class AiIntelligenceRepository {
  const AiIntelligenceRepository(this.api);

  final ApiClient api;

  String _inputPath(String projectId) =>
      '/api/projects/$projectId/input-intelligence';

  String _workflowPath(String projectId) =>
      '/api/projects/$projectId/workflow-intelligence';

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

  Future<Map<String, dynamic>> stageCandidate(
    String projectId,
    Map<String, dynamic> candidate,
  ) async {
    final payload = <String, dynamic>{
      'id': candidate['id'],
      'title': candidate['title'],
      'description': candidate['description'],
      'languageCode': candidate['languageCode'],
      'confidence': candidate['confidence'],
      'evidence': candidate['evidence'],
    };

    return _object(
      await api.post('${_workflowPath(projectId)}/candidates', payload),
    );
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
        '${_workflowPath(projectId)}/reviews/'
        '${Uri.encodeComponent(requirementId)}',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getClarifications(String projectId) async {
    final result = await api.get('${_workflowPath(projectId)}/clarifications');

    if (result is! List) {
      throw const FormatException('Invalid clarification response');
    }

    return result.map(_object).toList();
  }

  Future<Map<String, dynamic>> createClarification({
    required String projectId,
    required String requirementId,
    required String question,
    required String? expectedConcurrencyToken,
  }) async {
    final cleanQuestion = question.trim();

    if (requirementId.trim().isEmpty ||
        cleanQuestion.isEmpty ||
        cleanQuestion.length > 1500) {
      throw ArgumentError('A valid requirement and question are required');
    }

    return _object(
      await api.post('${_workflowPath(projectId)}/clarifications', {
        'expectedConcurrencyToken': expectedConcurrencyToken,
        'requirementId': requirementId,
        'question': cleanQuestion,
      }),
    );
  }

  Future<Map<String, dynamic>> answerClarification({
    required String projectId,
    required String questionId,
    required String expectedConcurrencyToken,
    required int expectedRevision,
    required String answer,
  }) async {
    final guid = RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
    );

    if (!guid.hasMatch(questionId) ||
        !guid.hasMatch(expectedConcurrencyToken) ||
        expectedRevision < 1 ||
        answer.trim().isEmpty) {
      throw ArgumentError('Invalid clarification answer request');
    }

    return _object(
      await api.post(
        '${_workflowPath(projectId)}/clarifications/$questionId/answer',
        {
          'expectedConcurrencyToken': expectedConcurrencyToken,
          'expectedRevision': expectedRevision,
          'answer': answer.trim(),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getReviewSyncStatus(String projectId) async {
    final result = _object(
      await api.get(
        '${_workflowPath(projectId)}/blueprints/review-sync-status',
      ),
    );

    if (result['projectId'] != projectId ||
        result['blueprintRevision'] is! int ||
        result['existingRequirementsSynchronized'] is! bool ||
        result['items'] is! List) {
      throw const FormatException('Invalid review synchronization response');
    }

    return result;
  }

  Map<String, dynamic> _blueprintResponse(dynamic value) {
    final response = _object(value);

    final token = response['concurrencyToken'];

    if (response['applied'] is! bool ||
        response['reason'] is! String ||
        response['draftVersion'] is! int ||
        (response['draftVersion'] as int) < 1 ||
        token is! String ||
        !RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
        ).hasMatch(token) ||
        token == '00000000-0000-0000-0000-000000000000' ||
        response['blueprint'] is! Map) {
      throw const FormatException('Invalid Blueprint workflow response');
    }

    return response;
  }

  Future<Map<String, dynamic>> generateBlueprint({
    required String projectId,
    required String? expectedConcurrencyToken,
    required String blueprintId,
    required List<String> confirmedRequirementIds,
    required List<Map<String, dynamic>> features,
    required List<Map<String, dynamic>> screens,
    required List<Map<String, dynamic>> components,
    required List<Map<String, dynamic>> actions,
    required List<Map<String, dynamic>> navigation,
  }) async {
    if (features.isEmpty || screens.isEmpty) {
      throw ArgumentError('Blueprint generation requires features and screens');
    }

    if (confirmedRequirementIds.isEmpty ||
        confirmedRequirementIds.length > 200 ||
        confirmedRequirementIds.toSet().length !=
            confirmedRequirementIds.length) {
      throw ArgumentError('Invalid confirmed requirement selection');
    }

    return _blueprintResponse(
      await api.post('${_workflowPath(projectId)}/blueprints/generate', {
        'expectedConcurrencyToken': expectedConcurrencyToken,
        'blueprintId': blueprintId,
        'confirmedRequirementIds': confirmedRequirementIds,
        'features': features,
        'screens': screens,
        'components': components,
        'actions': actions,
        'navigation': navigation,
      }),
    );
  }

  Future<Map<String, dynamic>> regenerateBlueprint({
    required String projectId,
    required String expectedConcurrencyToken,
    required int expectedRevision,
    required String languageCode,
    required String instructions,
    required bool consentGranted,
    required List<String> protectedFeatureIds,
    required List<String> protectedScreenIds,
    required List<String> protectedComponentIds,
  }) async {
    if (!consentGranted) {
      throw ArgumentError('AI processing consent is required');
    }

    if (instructions.trim().isEmpty) {
      throw ArgumentError('Design instructions are required');
    }

    return _blueprintResponse(
      await api.post('${_workflowPath(projectId)}/blueprints/regenerate', {
        'expectedConcurrencyToken': expectedConcurrencyToken,
        'languageCode': languageCode,
        'instructions': instructions,
        'consentGranted': consentGranted,
        'policy': {
          'expectedRevision': expectedRevision,
          'protectedFeatureIds': protectedFeatureIds,
          'protectedScreenIds': protectedScreenIds,
          'protectedComponentIds': protectedComponentIds,
        },
      }),
    );
  }
}
