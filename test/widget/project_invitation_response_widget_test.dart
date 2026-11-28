import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_invitation_response_page.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const editorId = '44444444-4444-4444-8444-444444444444';

void main() {
  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  testWidgets('invitation response remains usable on narrow mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProjectInvitationResponsePage(
            token: 'abcdefghijklmnopqrstuvwxyz1234567890',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired invitation displays a final-state error', (
    tester,
  ) async {
    final api = ApiClient(
      MockClient((_) async => response({'title': 'Expired'}, 409)),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: ProjectInvitationResponsePage(
            token: 'abcdefghijklmnopqrstuvwxyz1234567890',
          ),
        ),
      ),
    );
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('expired or has already been used'),
      findsOneWidget,
    );
  });

  testWidgets('acceptance refreshes the project list before navigation', (
    tester,
  ) async {
    var projectLoads = 0;
    final api = ApiClient(
      MockClient(
        (_) async => response({
          'projectId': projectId,
          'userId': editorId,
          'role': 'Editor',
          'joinedAt': '2026-11-27T09:00:00Z',
        }),
      ),
    );
    addTearDown(api.dispose);
    final router = GoRouter(
      initialLocation:
          '/project-invitations/respond?token=abcdefghijklmnopqrstuvwxyz1234567890',
      routes: [
        GoRoute(
          path: '/project-invitations/respond',
          builder:
              (_, state) => ProjectInvitationResponsePage(
                token: state.uri.queryParameters['token'] ?? '',
              ),
        ),
        GoRoute(
          path: '/projects/:id/overview',
          builder: (_, _) => const Text('Accepted project'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          projectsProvider.overrideWith((ref) async {
            projectLoads++;
            return [];
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(projectsProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(projectLoads, 1);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text('Accepted project'), findsOneWidget);
    expect(projectLoads, 2);
  });
}
