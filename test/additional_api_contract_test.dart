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
const concurrencyToken = 'd5859ac2-7a39-4f5a-b937-5f1b2b593333';

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

  test('Clarification list uses the workflow endpoint', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/projects/$projectId/workflow-intelligence/clarifications',
        );

        return http.Response('[]', 200);
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(
      api,
    ).getClarifications(projectId);

    expect(result, isEmpty);
  });

  test('Clarification creation preserves concurrency token', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/projects/$projectId/workflow-intelligence/clarifications',
        );
        expect(jsonDecode(request.body), {
          'expectedConcurrencyToken': concurrencyToken,
          'requirementId': 'REQ-001',
          'question': 'Which users need access?',
        });

        return http.Response(
          '{"clarification":{"revision":1},"version":2}',
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(api).createClarification(
      projectId: projectId,
      requirementId: 'REQ-001',
      question: 'Which users need access?',
      expectedConcurrencyToken: concurrencyToken,
    );

    expect(result['version'], 2);
  });

  test('Clarification answer includes expected revision', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/projects/$projectId/workflow-intelligence/'
          'clarifications/$questionId/answer',
        );
        expect(jsonDecode(request.body), {
          'expectedConcurrencyToken': concurrencyToken,
          'expectedRevision': 1,
          'answer': 'Project owners',
        });

        return http.Response(
          '{"clarification":{"revision":2},"version":3}',
          200,
        );
      }),
    );

    addTearDown(api.dispose);

    final result = await AiIntelligenceRepository(api).answerClarification(
      projectId: projectId,
      questionId: questionId,
      expectedConcurrencyToken: concurrencyToken,
      expectedRevision: 1,
      answer: 'Project owners',
    );

    expect(result['version'], 3);
  });

  test('Review sync reports the actual server synchronization state', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(
          request.url.path,
          '/api/projects/$projectId/workflow-intelligence/'
          'blueprints/review-sync-status',
        );

        return http.Response(
          jsonEncode({
            'projectId': projectId,
            'blueprintRevision': 2,
            'existingRequirementsSynchronized': false,
            'items': [],
          }),
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
