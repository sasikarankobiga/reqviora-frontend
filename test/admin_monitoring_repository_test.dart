import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_monitoring_repository.dart';
import 'package:reqviora_frontend/features/administration/domain/admin_monitoring_models.dart';

const jobId = '87d7a096-af02-4ec3-98ae-51f313a02111';
const projectId = '8bcdd3d4-40f9-4f26-8078-f4ab58122111';

Map<String, Object?> validation({int attempts = 4}) => {
  'attempts': attempts,
  'succeeded': attempts - 1,
  'failed': 1,
  'successRate': attempts == 0 ? 0 : 75.0,
  'failureRate': attempts == 0 ? 0 : 25.0,
  'averageDurationMilliseconds': 125.5,
  'errors': {
    'schema': 1,
    'brokenReferences': 2,
    'unsupportedComponents': 3,
    'navigation': 4,
    'other': 5,
  },
};

Map<String, Object?> job({String status = 'processing'}) => {
  'id': jobId,
  'projectId': projectId,
  'type': 'completion',
  'status': status,
  'attempts': 2,
  'maxAttempts': 3,
  'createdAt': '2026-11-28T01:00:00Z',
  'startedAt': '2026-11-28T01:01:00Z',
  'completedAt': status == 'completed' ? '2026-11-28T01:02:00Z' : null,
  'durationMilliseconds': status == 'completed' ? 60000 : null,
  'failureCategory': status == 'failed' ? 'timeout' : null,
  'expiredLease': false,
  'stale': false,
};

Map<String, Object?> statistics() => {
  'pending': 1,
  'processing': 2,
  'completed': 3,
  'failed': 4,
  'cancelled': 5,
  'retryAttempts': 6,
  'retriedJobs': 2,
  'expiredLeases': 1,
  'staleJobs': 1,
  'oldestPendingSeconds': 30.0,
  'averagePendingAgeSeconds': 12.5,
  'averageProcessingMilliseconds': 550.0,
  'providerFailures': 2,
  'timeouts': 1,
};

Map<String, Object?> health() => {
  'providerStatus': 'degraded',
  'localWorkerStatus': 'healthy',
  'lastLocalPoll': '2026-11-28T01:03:00Z',
  'queueStatus': 'degraded',
  'staleJobs': 1,
};

void startSession() {
  authSession.startSession(
    accessToken: 'admin-access',
    refreshToken: 'admin-refresh',
    accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

void main() {
  setUp(startSession);
  tearDown(authSession.signOut);

  test('parses backend-authoritative validation summary and trends', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer admin-access');
        expect(request.url.queryParameters, {
          'from': '2026-11-01',
          'to': '2026-11-28',
        });
        if (request.url.path.endsWith('/summary')) {
          return http.Response(jsonEncode(validation()), 200);
        }
        expect(request.url.path, '/api/admin/validation/trends');
        return http.Response(
          jsonEncode([
            {'date': '2026-11-28', 'statistics': validation()},
          ]),
          200,
        );
      }),
    );
    addTearDown(api.dispose);

    final result = await AdminMonitoringRepository(
      api,
    ).validationHealth(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 28));

    expect(result.summary.attempts, 4);
    expect(result.summary.errors.total, 15);
    expect(result.trends.single.statistics.failed, 1);
  });

  test('rejects inconsistent or private-shaped validation payloads', () {
    final raw = validation()..['attempts'] = 99;
    expect(
      () => ValidationStatistics.fromJson(raw),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => ValidationErrorCounts.fromJson({'stackTrace': 'private'}),
      throwsA(isA<ApiException>()),
    );
  });

  test('parses AI directory, statistics, health and backend filters', () async {
    final paths = <String>[];
    final api = ApiClient(
      MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/api/admin/ai-jobs') {
          expect(request.url.queryParameters['status'], 'processing');
          expect(request.url.queryParameters['type'], 'completion');
          expect(request.url.queryParameters['page'], '2');
          return http.Response(
            jsonEncode({
              'page': 2,
              'pageSize': 20,
              'total': 21,
              'items': [job()],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/summary')) {
          return http.Response(jsonEncode(statistics()), 200);
        }
        return http.Response(jsonEncode(health()), 200);
      }),
    );
    addTearDown(api.dispose);

    final result = await AdminMonitoringRepository(
      api,
    ).aiQueue(page: 2, status: AdminAiJobStatus.processing, type: 'completion');

    expect(result.jobs.items.single.status, AdminAiJobStatus.processing);
    expect(result.statistics.retryAttempts, 6);
    expect(result.health.providerStatus, 'degraded');
    expect(
      paths,
      containsAll([
        '/api/admin/ai-jobs',
        '/api/admin/ai-jobs/summary',
        '/api/admin/ai-jobs/health',
      ]),
    );
  });

  test('maps timeout safely without accepting raw diagnostics', () {
    final parsed = AdminAiJob.fromJson(job(status: 'failed'));
    expect(parsed.timedOut, isTrue);
    expect(parsed.failureCategory, 'timeout');
    final unsafe = job(status: 'failed')
      ..['failureCategory'] = 'secret-api-key';
    expect(() => AdminAiJob.fromJson(unsafe), throwsA(isA<ApiException>()));
  });

  test('unsupported states and invalid pagination are rejected', () {
    expect(
      () => AdminAiJob.fromJson(job(status: 'retrying')),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => AdminAiJobPage.fromJson({
        'page': 1,
        'pageSize': 101,
        'total': 0,
        'items': [],
      }),
      throwsA(isA<ApiException>()),
    );
  });

  test('unauthenticated access stops before HTTP', () async {
    authSession.signOut();
    var calls = 0;
    final api = ApiClient(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.dispose);
    await expectLater(
      AdminMonitoringRepository(api).validationHealth(),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    expect(calls, 0);
  });

  test('session change rejects stale monitoring response', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final api = ApiClient(
      MockClient((request) async {
        if (!started.isCompleted) started.complete();
        return response.future;
      }),
    );
    addTearDown(api.dispose);
    final pending = AdminMonitoringRepository(api).validationHealth();
    await started.future;
    authSession.signOut();
    response.complete(http.Response(jsonEncode(validation()), 200));
    await expectLater(pending, throwsA(isA<ApiException>()));
  });
}
