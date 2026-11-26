import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/application/auth_providers.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/background_jobs/presentation/pages/ai_job_page.dart';

const jobId = '11111111-1111-4111-8111-111111111111';
const ownerId = '22222222-2222-4222-8222-222222222222';

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository(api)),
        ],
        child: const MaterialApp(home: AiJobPage(pollInterval: Duration.zero)),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('AI submission requires consent', (tester) async {
    await open(tester, (request) async {
      fail('No API request is expected');
    });

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('ai-job-submit')),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('Submitted job displays its completed result', (tester) async {
    var calls = 0;

    await open(tester, (request) async {
      calls++;

      if (request.method == 'POST') {
        expect(request.url.path, '/api/ai/jobs');
        expect(jsonDecode(request.body)['prompt'], 'Design a dashboard');

        return http.Response(jsonEncode({'id': jobId, 'state': 'queued'}), 202);
      }

      expect(request.url.path, '/api/ai/jobs/$jobId');

      return http.Response(
        jsonEncode({
          'id': jobId,
          'ownerId': ownerId,
          'state': 'completed',
          'result': 'Dashboard design suggestion',
          'error': null,
        }),
        200,
      );
    });

    await tester.enterText(
      find.byKey(const ValueKey('ai-job-prompt')),
      'Design a dashboard',
    );

    await tester.tap(find.byKey(const ValueKey('ai-job-consent')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ai-job-submit')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Dashboard design suggestion'), findsOneWidget);

    authSession.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Dashboard design suggestion'), findsNothing);
    expect(find.text('Completed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Submission failure displays a safe message', (tester) async {
    await open(tester, (request) async {
      return http.Response('{"title":"Private provider diagnostic"}', 503);
    });

    await tester.enterText(
      find.byKey(const ValueKey('ai-job-prompt')),
      'Design a dashboard',
    );

    await tester.tap(find.byKey(const ValueKey('ai-job-consent')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('ai-job-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Submission could not be confirmed. Do not retry automatically.',
      ),
      findsOneWidget,
    );

    expect(find.text('Private provider diagnostic'), findsNothing);
    expect(find.byKey(const ValueKey('ai-job-result')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
