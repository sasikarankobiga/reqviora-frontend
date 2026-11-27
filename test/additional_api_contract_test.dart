import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/workspace/data/ai_intelligence_repository.dart';

const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';
const questionId = 'd5859ac2-7a39-4f5a-b937-5f1b2b592222';
void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  test('Account profile uses the authenticated user endpoint', () async {
    authSession.signIn('test-access');

    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/users/me');
        expect(request.headers['Authorization'], 'Bearer test-access');

        return http.Response(
          '{"displayName":"Test User","email":"test@example.com"}',
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    final profile = await AuthRepository(api).getProfile();

    expect(profile['email'], 'test@example.com');
  });

  test('Email change sends the new address without changing session', () async {
    authSession.signIn('test-access');

    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/account-security/email-change/request');
        expect(jsonDecode(request.body), {'newEmail': 'new@example.com'});

        return http.Response('', 202);
      }),
    );

    addTearDown(api.dispose);

    await AuthRepository(api).requestEmailChange(' new@example.com ');

    expect(authSession.token, 'test-access');
  });

  test('Email confirmation clears local authentication session', () async {
    authSession.signIn('test-access');

    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/account-security/email-change/confirm');
        expect(jsonDecode(request.body), {'token': 'test-token'});

        return http.Response('', 204);
      }),
    );

    addTearDown(api.dispose);

    await AuthRepository(api).confirmEmailChange('test-token');

    expect(authSession.authenticated, isFalse);
  });

  test('Failed email confirmation preserves current session', () async {
    authSession.signIn('test-access');

    final api = ApiClient(
      MockClient((request) async {
        return http.Response('{}', 400);
      }),
    );

    addTearDown(api.dispose);

    await expectLater(
      AuthRepository(api).confirmEmailChange('invalid-token'),
      throwsA(isA<ApiException>()),
    );

    expect(authSession.token, 'test-access');
  });

  test('Clarification list uses the requirement-scoped endpoint', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/projects/$projectId/requirements/candidates/'
          'REQ-001/clarifications',
        );

        return http.Response('[]', 200);
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(
      api,
    ).getClarifications(projectId, requirementId: 'REQ-001');

    expect(result, isEmpty);
  });

  test('Clarification creation uses the backend request DTO', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/projects/$projectId/requirements/candidates/'
          'REQ-001/clarifications',
        );
        expect(jsonDecode(request.body), {
          'question': 'Which users need access?',
        });

        return http.Response(
          '{"id":"$questionId","requirementId":"REQ-001",'
          '"question":"Which users need access?","revision":1}',
          201,
        );
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(api).createClarification(
      projectId: projectId,
      requirementId: 'REQ-001',
      question: 'Which users need access?',
    );

    expect(result['revision'], 1);
  });

  test('Clarification answer includes expected revision', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/projects/$projectId/requirements/candidates/'
          'REQ-001/clarifications/$questionId/answer',
        );
        expect(jsonDecode(request.body), {
          'expectedRevision': 1,
          'answer': 'Project owners',
        });

        return http.Response(
          '{"id":"$questionId","requirementId":"REQ-001",'
          '"question":"Which users need access?",'
          '"answer":"Project owners","revision":2}',
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(api).answerClarification(
      projectId: projectId,
      requirementId: 'REQ-001',
      questionId: questionId,
      expectedRevision: 1,
      answer: 'Project owners',
    );

    expect(result['revision'], 2);
  });

  test('Review sync reports the actual server synchronization state', () async {
    final api = ApiClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/requirements/candidates')) {
          expect(request.url.queryParameters, {'offset': '0', 'limit': '100'});
          return http.Response(
            '[{"id":"REQ-001","status":"confirmed","revision":2}]',
            200,
          );
        }

        expect(request.url.path, '/api/projects/$projectId/blueprints/current');
        return http.Response(
          '{"blueprint":{"revision":2,"requirements":[]}}',
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(
      api,
    ).getReviewSyncStatus(projectId);

    expect(result['existingRequirementsSynchronized'], isFalse);
  });
}
