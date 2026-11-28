import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/application/admin_monitoring_providers.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_monitoring_repository.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/ai_queue_monitoring_page.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/validation_health_page.dart';

const _jobId = '87d7a096-af02-4ec3-98ae-51f313a02111';
const _projectId = '8bcdd3d4-40f9-4f26-8078-f4ab58122111';

Map<String, Object?> _validation() => {
  'attempts': 4,
  'succeeded': 3,
  'failed': 1,
  'successRate': 75.0,
  'failureRate': 25.0,
  'averageDurationMilliseconds': 125.5,
  'errors': {
    'schema': 1,
    'brokenReferences': 2,
    'unsupportedComponents': 3,
    'navigation': 4,
    'other': 5,
  },
};

Map<String, Object?> _queuePage() => {
  'page': 1,
  'pageSize': 20,
  'total': 1,
  'items': [
    {
      'id': _jobId,
      'projectId': _projectId,
      'type': 'completion',
      'status': 'processing',
      'attempts': 1,
      'maxAttempts': 3,
      'createdAt': '2026-11-28T01:00:00Z',
      'startedAt': '2026-11-28T01:01:00Z',
      'completedAt': null,
      'durationMilliseconds': null,
      'failureCategory': null,
      'expiredLease': false,
      'stale': false,
    },
  ],
};

Map<String, Object?> _statistics() => {
  'pending': 0,
  'processing': 1,
  'completed': 0,
  'failed': 0,
  'cancelled': 0,
  'retryAttempts': 0,
  'retriedJobs': 0,
  'expiredLeases': 0,
  'staleJobs': 0,
  'oldestPendingSeconds': null,
  'averagePendingAgeSeconds': null,
  'averageProcessingMilliseconds': null,
  'providerFailures': 0,
  'timeouts': 0,
};

Map<String, Object?> _health() => {
  'providerStatus': 'unknown',
  'localWorkerStatus': 'healthy',
  'lastLocalPoll': '2026-11-28T01:03:00Z',
  'queueStatus': 'healthy',
  'staleJobs': 0,
};

void _session() {
  authSession.startSession(
    accessToken: 'admin-access',
    refreshToken: 'admin-refresh',
    accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

Future<void> _open(WidgetTester tester, Widget page, MockClient client) async {
  final api = ApiClient(client);
  addTearDown(api.dispose);
  await tester.binding.setSurfaceSize(const Size(1280, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminMonitoringRepositoryProvider.overrideWithValue(
          AdminMonitoringRepository(api),
        ),
      ],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(_session);
  tearDown(authSession.signOut);

  testWidgets('validation dashboard renders real aggregate telemetry', (
    tester,
  ) async {
    await _open(
      tester,
      const ValidationHealthPage(),
      MockClient((request) async {
        if (request.url.path.endsWith('/summary')) {
          return http.Response(jsonEncode(_validation()), 200);
        }
        return http.Response(
          jsonEncode([
            {'date': '2026-11-28', 'statistics': _validation()},
          ]),
          200,
        );
      }),
    );

    await tester.tap(find.byKey(const ValueKey('validation-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('Broken references'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('Blueprint contents'), findsOneWidget);
    expect(find.textContaining('Project-level attempts'), findsOneWidget);
  });

  testWidgets('AI queue renders sanitized jobs and provider health', (
    tester,
  ) async {
    await _open(
      tester,
      const AiQueueMonitoringPage(),
      MockClient((request) async {
        if (request.url.path == '/api/admin/ai-jobs') {
          return http.Response(jsonEncode(_queuePage()), 200);
        }
        if (request.url.path.endsWith('/summary')) {
          return http.Response(jsonEncode(_statistics()), 200);
        }
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode(_health()), 200);
        }
        return http.Response(
          jsonEncode((_queuePage()['items']! as List).first),
          200,
        );
      }),
    );

    await tester.tap(find.byKey(const ValueKey('ai-queue-refresh')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-queue-job-$_jobId')), findsOneWidget);
    expect(find.textContaining('Provider: unknown'), findsOneWidget);
    expect(
      find.textContaining('Prompts, responses, credentials'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No unsupported action is simulated'),
      findsOneWidget,
    );
  });

  testWidgets('polling never overlaps and stops when disposed', (tester) async {
    var calls = 0;
    final gates = <Completer<http.Response>>[];
    await _open(
      tester,
      const AiQueueMonitoringPage(pollInterval: Duration(milliseconds: 20)),
      MockClient((request) {
        calls++;
        final gate = Completer<http.Response>();
        gates.add(gate);
        return gate.future;
      }),
    );

    await tester.tap(find.byKey(const ValueKey('ai-queue-polling')));
    await tester.tap(find.byKey(const ValueKey('ai-queue-refresh')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 3);

    for (var i = 0; i < gates.length; i++) {
      final body =
          i == 0
              ? _queuePage()
              : i == 1
              ? _statistics()
              : _health();
      gates[i].complete(http.Response(jsonEncode(body), 200));
    }
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final callsAtDispose = calls;
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, callsAtDispose);
  });

  testWidgets('authorization failure is safe and stops polling', (
    tester,
  ) async {
    await _open(
      tester,
      const AiQueueMonitoringPage(pollInterval: Duration(milliseconds: 20)),
      MockClient((_) async => http.Response('private stack trace', 403)),
    );

    await tester.tap(find.byKey(const ValueKey('ai-queue-polling')));
    await tester.tap(find.byKey(const ValueKey('ai-queue-refresh')));
    await tester.pumpAndSettle();

    expect(
      find.text('Administrator access with MFA is required.'),
      findsOneWidget,
    );
    expect(find.textContaining('private stack trace'), findsNothing);
    final toggle = tester.widget<Switch>(
      find.byKey(const ValueKey('ai-queue-polling')),
    );
    expect(toggle.value, isFalse);
  });
}
