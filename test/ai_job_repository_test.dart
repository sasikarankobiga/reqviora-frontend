import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/background_jobs/data/repositories/ai_job_repository.dart';

const jobId = '11111111-1111-4111-8111-111111111111';
const ownerId = '22222222-2222-4222-8222-222222222222';

http.Response jobResponse(
  String state, {
  String id = jobId,
  String? result,
  String? error,
}) {
  return http.Response(
    jsonEncode({
      'id': id,
      'ownerId': ownerId,
      'state': state,
      'result': result,
      'error': error,
    }),
    200,
  );
}

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  AiJobRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);

    return AiJobRepository(api);
  }

  test('Submits an AI job using the verified contract', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/ai/jobs');
      expect(request.headers['Authorization'], 'Bearer test-session');
      expect(jsonDecode(request.body), {'prompt': 'Generate design'});

      return http.Response(jsonEncode({'id': jobId, 'state': 'queued'}), 202);
    });

    final job = await repo.submit(' Generate design ');

    expect(job.id, jobId);
    expect(job.state, AiJobState.queued);
    expect(job.isTerminal, isFalse);
  });

  test('Rejects empty or oversized prompts before HTTP', () async {
    final repo = repository((request) async {
      fail('Invalid prompt must not reach the API');
    });

    await expectLater(repo.submit('   '), throwsArgumentError);

    await expectLater(
      repo.submit(List.filled(100001, 'x').join()),
      throwsArgumentError,
    );
  });

  test('Rejects malformed job receipts', () async {
    final repo = repository((request) async {
      return http.Response('{"id":"invalid","state":"queued"}', 202);
    });

    await expectLater(
      repo.submit('Generate design'),
      throwsA(isA<ApiException>()),
    );
  });

  test('Rejects invalid job IDs before HTTP', () async {
    final repo = repository((request) async {
      fail('Invalid ID must not reach the API');
    });

    await expectLater(
      repo.getStatus('../another-project'),
      throwsArgumentError,
    );
  });

  test('Polls queued running and completed states', () async {
    var calls = 0;
    final states = <AiJobState>[];

    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/ai/jobs/$jobId');

      calls++;

      if (calls == 1) return jobResponse('queued');
      if (calls == 2) return jobResponse('running');

      return jobResponse('completed', result: 'Generated result');
    });

    final result = await repo.poll(
      jobId,
      interval: Duration.zero,
      maxAttempts: 5,
      onStatus: (status) => states.add(status.state),
    );

    expect(calls, 3);
    expect(result.result, 'Generated result');
    expect(result.isTerminal, isTrue);

    expect(states, [
      AiJobState.queued,
      AiJobState.running,
      AiJobState.completed,
    ]);
  });

  test('Failed job stops polling with a sanitized message', () async {
    var calls = 0;

    final repo = repository((request) async {
      calls++;

      return jobResponse('failed', error: 'Internal provider diagnostic');
    });

    final result = await repo.poll(jobId, interval: Duration.zero);

    expect(calls, 1);
    expect(result.state, AiJobState.failed);
    expect(result.result, isNull);
    expect(result.failureMessage, 'AI provider request failed.');
  });

  test('Rejects unknown states and mismatched job identity', () async {
    var calls = 0;

    final repo = repository((request) async {
      calls++;

      if (calls == 1) {
        return jobResponse('unexpected');
      }

      return jobResponse('running', id: ownerId);
    });

    await expectLater(repo.getStatus(jobId), throwsA(isA<ApiException>()));

    await expectLater(repo.getStatus(jobId), throwsA(isA<ApiException>()));
  });

  test('Polling stops at its configured attempt limit', () async {
    var calls = 0;

    final repo = repository((request) async {
      calls++;
      return jobResponse('running');
    });

    await expectLater(
      repo.poll(jobId, interval: Duration.zero, maxAttempts: 2),
      throwsA(isA<AiJobPollingTimeout>()),
    );

    expect(calls, 2);
  });

  test('Cancelled polling makes no HTTP request', () async {
    final repo = repository((request) async {
      fail('Cancelled polling must not access the API');
    });

    await expectLater(
      repo.poll(jobId, isCancelled: () => true),
      throwsA(isA<AiJobPollingCancelled>()),
    );
  });

  test('Session changes prevent additional polling requests', () async {
    var calls = 0;

    final repo = repository((request) async {
      calls++;
      return jobResponse('running');
    });

    await expectLater(
      repo.poll(
        jobId,
        interval: Duration.zero,
        onStatus: (_) => authSession.signIn('new-session'),
      ),
      throwsA(isA<ApiException>()),
    );

    expect(calls, 1);
    expect(authSession.token, 'new-session');
  });
}
