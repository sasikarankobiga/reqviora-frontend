import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/ai_intelligence_repository.dart';

void main() {
  late AiIntelligenceRepository repository;

  const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';
  const token = '11111111-1111-4111-8111-111111111111';
  final evidence = <Map<String, dynamic>>[
    {
      'sourceId': 'source-1',
      'locator': 'text:0-19',
      'quote': 'Users must sign in.',
    },
  ];
  final candidate = <String, dynamic>{
    'id': 'REQ-001',
    'title': 'Sign in',
    'description': 'Users must sign in.',
    'languageCode': 'en',
    'confidence': 0.95,
    'evidence': evidence,
  };

  void configure(Future<http.Response> Function(http.Request) handler) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    repository = AiIntelligenceRepository(api);
  }

  http.Response response(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('AI extraction uses the input intelligence contract', () async {
    configure((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/projects/$projectId/input-intelligence/requirements/extract',
      );
      final body = jsonDecode(request.body) as Map;
      expect(body['languageCode'], 'en');
      expect(body['consentGranted'], isTrue);
      expect(body['evidence'], evidence);
      return response({
        'contractVersion': '1.0',
        'candidates': [candidate],
      });
    });

    final result = await repository.extractRequirements(
      projectId: projectId,
      languageCode: 'en',
      inputText: 'Users must sign in.',
      evidence: evidence,
      consentGranted: true,
    );

    expect(result.single['id'], 'REQ-001');
  });

  test('Extraction without consent never calls API', () async {
    configure((request) async => throw StateError('unexpected request'));

    await expectLater(
      repository.extractRequirements(
        projectId: projectId,
        languageCode: 'en',
        inputText: 'Users must sign in.',
        evidence: evidence,
        consentGranted: false,
      ),
      throwsArgumentError,
    );
  });

  test('Empty source text never calls API', () async {
    configure((request) async => throw StateError('unexpected request'));

    await expectLater(
      repository.extractRequirements(
        projectId: projectId,
        languageCode: 'en',
        inputText: '   ',
        evidence: evidence,
        consentGranted: true,
      ),
      throwsArgumentError,
    );
  });

  test('Malformed extraction response is rejected', () async {
    configure((request) async => response({'candidates': 'invalid'}));

    await expectLater(
      repository.extractRequirements(
        projectId: projectId,
        languageCode: 'en',
        inputText: 'Users must sign in.',
        evidence: evidence,
        consentGranted: true,
      ),
      throwsFormatException,
    );
  });

  test('Review status uses the backend candidate resource', () async {
    configure((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/projects/$projectId/requirements/candidates/REQ-001',
      );
      return response({'id': 'REQ-001', 'status': 'suggested', 'revision': 1});
    });

    final result = await repository.getReview(projectId, 'REQ-001');
    expect(result['revision'], 1);
  });

  test('Blueprint generation sends only the authoritative DTO', () async {
    configure((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/projects/$projectId/blueprints/generate');
      expect(jsonDecode(request.body), {
        'expectedConcurrencyToken': token,
        'requirementIds': ['REQ-001'],
      });
      return response({
        'version': 2,
        'concurrencyToken': token,
        'draft': <String, dynamic>{},
      });
    });

    final result = await repository.generateBlueprint(
      projectId: projectId,
      expectedConcurrencyToken: token,
      confirmedRequirementIds: ['REQ-001'],
    );

    expect(result['version'], 2);
  });

  test('Duplicate confirmed requirements are rejected locally', () async {
    configure((request) async => throw StateError('unexpected request'));

    await expectLater(
      repository.generateBlueprint(
        projectId: projectId,
        expectedConcurrencyToken: token,
        confirmedRequirementIds: ['REQ-001', 'REQ-001'],
      ),
      throwsArgumentError,
    );
  });

  test('More than fifty requirements are rejected locally', () async {
    configure((request) async => throw StateError('unexpected request'));

    await expectLater(
      repository.generateBlueprint(
        projectId: projectId,
        expectedConcurrencyToken: token,
        confirmedRequirementIds: List.generate(51, (index) => 'REQ-$index'),
      ),
      throwsArgumentError,
    );
  });

  test('Regeneration maps editable IDs to the current backend DTO', () async {
    configure((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/projects/$projectId/blueprints/regenerate',
      );
      expect(jsonDecode(request.body), {
        'expectedConcurrencyToken': token,
        'expectedRevision': 3,
        'editableFeatureIds': ['FEAT-001'],
        'editableScreenIds': <String>[],
        'editableComponentIds': ['CMP-001'],
      });
      return response({
        'version': 4,
        'concurrencyToken': token,
        'draft': <String, dynamic>{},
      });
    });

    final result = await repository.regenerateBlueprint(
      projectId: projectId,
      expectedConcurrencyToken: token,
      expectedRevision: 3,
      editableFeatureIds: const ['FEAT-001'],
      editableScreenIds: const [],
      editableComponentIds: const ['CMP-001'],
    );

    expect(result['version'], 4);
  });

  test('Malformed project draft response is rejected', () async {
    configure((request) async => response({'version': 2}));

    await expectLater(
      repository.generateBlueprint(
        projectId: projectId,
        expectedConcurrencyToken: token,
        confirmedRequirementIds: ['REQ-001'],
      ),
      throwsFormatException,
    );
  });

  test('Invalid regeneration revision never calls API', () async {
    configure((request) async => throw StateError('unexpected request'));

    await expectLater(
      repository.regenerateBlueprint(
        projectId: projectId,
        expectedConcurrencyToken: token,
        expectedRevision: 0,
        editableFeatureIds: const [],
        editableScreenIds: const [],
        editableComponentIds: const [],
      ),
      throwsArgumentError,
    );
  });

  test('Project clarification list follows candidate-scoped routes', () async {
    configure((request) async {
      if (request.url.path.endsWith('/requirements/candidates')) {
        return response([
          {'id': 'REQ-001'},
          {'id': 'REQ-002'},
        ]);
      }
      if (request.url.path.endsWith('/REQ-001/clarifications')) {
        return response([
          {'id': 'question-1', 'requirementId': 'REQ-001'},
        ]);
      }
      expect(request.url.path, endsWith('/REQ-002/clarifications'));
      return response(<Object>[]);
    });

    final result = await repository.getClarifications(projectId);
    expect(result.single['requirementId'], 'REQ-001');
  });

  test('Unavailable AI provider preserves HTTP 503', () async {
    configure((request) async => response({'title': 'Unavailable'}, 503));

    await expectLater(
      repository.extractRequirements(
        projectId: projectId,
        languageCode: 'en',
        inputText: 'Users must sign in.',
        evidence: evidence,
        consentGranted: true,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });
}
