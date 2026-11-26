import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/data/ai_intelligence_repository.dart';

void main() {
  late AiIntelligenceRepository repository;

  final evidence = <Map<String, dynamic>>[
    {
      'sourceId': 'source-1',
      'locator': 'text:0-19',
      'pageNumber': null,
      'startOffset': 0,
      'endOffset': 19,
      'quote': 'Users must sign in.',
    },
  ];

  final candidate = <String, dynamic>{
    'id': 'REQ-001',
    'title': 'Sign in',
    'description': 'Users must sign in.',
    'languageCode': 'en',
    'confidence': 0.95,
    'evidence': [
      {
        'sourceId': 'source-1',
        'locator': 'text:0-19',
        'quote': 'Users must sign in.',
      },
    ],
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

  Future<List<Map<String, dynamic>>> extract({
    bool consent = true,
    String text = 'Users must sign in.',
  }) => repository.extractRequirements(
    projectId: 'project-1',
    languageCode: 'en',
    inputText: text,
    evidence: evidence,
    consentGranted: consent,
  );

  test('AI extraction sends correct request contract', () async {
    configure((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/api/projects/project-1/input-intelligence/requirements/extract',
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

    final result = await extract();

    expect(result.single['id'], 'REQ-001');
    expect(result.single['confidence'], 0.95);
  });

  test('Extraction without consent never calls API', () async {
    configure((request) async {
      fail('API must not be called without consent');
    });

    await expectLater(extract(consent: false), throwsArgumentError);
  });

  test('Empty source text is rejected', () async {
    configure((request) async {
      fail('API must not be called for empty text');
    });

    await expectLater(extract(text: '   '), throwsArgumentError);
  });

  test('Unavailable AI provider preserves HTTP 503', () async {
    configure((request) async {
      return response({'title': 'AI provider approval is pending.'}, 503);
    });

    await expectLater(
      extract(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('Malformed extraction response is rejected', () async {
    configure((request) async {
      return response({'candidates': 'invalid'});
    });

    await expectLater(extract(), throwsFormatException);
  });

  test('Candidate staging preserves evidence', () async {
    configure((request) async {
      expect(request.method, 'POST');

      expect(
        request.url.path,
        '/api/projects/project-1/workflow-intelligence/candidates',
      );

      final body = jsonDecode(request.body) as Map;

      expect(body['id'], candidate['id']);
      expect(body['evidence'], candidate['evidence']);

      return response({'id': 'REQ-001', 'status': 0, 'revision': 1}, 201);
    });

    final result = await repository.stageCandidate('project-1', candidate);

    expect(result['status'], 0);
    expect(result['revision'], 1);
  });

  test('Review status is retrieved from backend', () async {
    configure((request) async {
      expect(request.method, 'GET');

      expect(
        request.url.path,
        '/api/projects/project-1/workflow-intelligence/reviews/REQ-001',
      );

      return response({'id': 'REQ-001', 'status': 1, 'revision': 2});
    });

    final result = await repository.getReview('project-1', 'REQ-001');

    expect(result['status'], 1);
    expect(result['revision'], 2);
  });

  test('Blueprint generation sends concurrency token', () async {
    configure((request) async {
      expect(
        request.url.path,
        '/api/projects/project-1/workflow-intelligence/blueprints/generate',
      );

      final body = jsonDecode(request.body) as Map;

      expect(body['expectedConcurrencyToken'], 'token-1');
      expect(body['confirmedRequirementIds'], ['REQ-001']);
      expect(body['blueprintId'], 'BP-001');

      return response({
        'applied': true,
        'draftVersion': 2,
        'concurrencyToken': '11111111-1111-4111-8111-111111111111',
        'reason': 'APPLIED',
        'blueprint': {'blueprintId': 'BP-001'},
      });
    });

    final result = await repository.generateBlueprint(
      projectId: 'project-1',
      expectedConcurrencyToken: 'token-1',
      blueprintId: 'BP-001',
      confirmedRequirementIds: ['REQ-001'],
      features: [
        {
          'id': 'FEAT-001',
          'name': 'Authentication',
          'requirementIds': ['REQ-001'],
        },
      ],
      screens: [
        {
          'id': 'SCR-001',
          'name': 'Login',
          'featureIds': ['FEAT-001'],
        },
      ],
      components: [],
      actions: [],
      navigation: [],
    );

    expect(result['applied'], isTrue);
  });

  test('Duplicate confirmed requirements are rejected', () async {
    configure((request) async {
      fail('Duplicate selection must not reach API');
    });

    await expectLater(
      repository.generateBlueprint(
        projectId: 'project-1',
        expectedConcurrencyToken: null,
        blueprintId: 'BP-001',
        confirmedRequirementIds: ['REQ-001', 'REQ-001'],
        features: [],
        screens: [],
        components: [],
        actions: [],
        navigation: [],
      ),
      throwsArgumentError,
    );
  });

  test('AI regeneration requires consent', () async {
    configure((request) async {
      fail('Regeneration must require consent');
    });

    await expectLater(
      repository.regenerateBlueprint(
        projectId: 'project-1',
        expectedConcurrencyToken: 'token-1',
        expectedRevision: 1,
        languageCode: 'ta',
        instructions: 'Improve the layout',
        consentGranted: false,
        protectedFeatureIds: [],
        protectedScreenIds: [],
        protectedComponentIds: [],
      ),
      throwsArgumentError,
    );
  });

  test('Unsupported extraction contract is rejected', () async {
    configure((request) async {
      return response({
        'contractVersion': '2.0',
        'candidates': [candidate],
      });
    });

    await expectLater(extract(), throwsFormatException);
  });

  test('Empty Blueprint features and screens are rejected', () async {
    configure((request) async {
      fail('Invalid proposal must not reach the API');
    });

    await expectLater(
      repository.generateBlueprint(
        projectId: 'project-1',
        expectedConcurrencyToken: null,
        blueprintId: 'BP-001',
        confirmedRequirementIds: ['REQ-001'],
        features: [],
        screens: [],
        components: [],
        actions: [],
        navigation: [],
      ),
      throwsArgumentError,
    );
  });

  test('Incomplete regeneration response is rejected', () async {
    configure((request) async {
      return response({'applied': true});
    });

    await expectLater(
      repository.regenerateBlueprint(
        projectId: 'project-1',
        expectedConcurrencyToken: '11111111-1111-4111-8111-111111111111',
        expectedRevision: 1,
        languageCode: 'en',
        instructions: 'Improve layout',
        consentGranted: true,
        protectedFeatureIds: [],
        protectedScreenIds: [],
        protectedComponentIds: [],
      ),
      throwsFormatException,
    );
  });
}
