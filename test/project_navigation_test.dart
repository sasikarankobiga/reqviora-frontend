
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:reqviora_frontend/features/authentication/domain/models/auth_session.dart';
import 'package:reqviora_frontend/features/authentication/presentation/providers/auth_provider.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project_model.dart';
import 'package:reqviora_frontend/features/projects/presentation/providers/project_provider.dart';
import 'package:reqviora_frontend/features/projects/presentation/widgets/project_list_widget.dart';

// Fake authentication used only for automated testing.
class FakeAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async {
    return AuthSession(
      userId: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User',
      accessToken: 'test-access-token',
      accessTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(hours: 1),
      ),
      refreshToken: 'test-refresh-token',
      refreshTokenExpiresAt: DateTime.now().toUtc().add(
        const Duration(days: 7),
      ),
      tokenType: 'Bearer',
    );
  }
}

void main() {
  testWidgets(
    'Project card opens the correct project overview route',
    (WidgetTester tester) async {
      const projectId = '11111111-1111-4111-8111-111111111111';

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) {
              return const Scaffold(
                body: SingleChildScrollView(
                  child: ProjectListWidget(),
                ),
              );
            },
          ),
          GoRoute(
            path: '/projects/:projectId',
            builder: (context, state) {
              final id = state.pathParameters['projectId'];

              return Scaffold(
                body: Center(
                  child: Text('Overview: $id'),
                ),
              );
            },
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              FakeAuthController.new,
            ),

            // Mock project list, without calling the backend.
            projectListProvider.overrideWith(
              (ref) async {
                return [
                  ProjectModel(
                    id: projectId,
                    name: 'Test Project',
                    description: 'Project navigation test',
                    ownerId: 'test-user-id',
                    createdAt: DateTime.utc(2026, 1, 1),
                  ),
                ];
              },
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // TEST 1: Mock project appears in the list.
      expect(
        find.text('Test Project'),
        findsOneWidget,
      );

      // TEST 2: Click the project card.
      await tester.ensureVisible(
        find.text('Test Project'),
      );

      await tester.tap(
        find.text('Test Project'),
      );

      await tester.pumpAndSettle();

      // TEST 3: Correct overview route is opened.
      expect(
        find.text('Overview: $projectId'),
        findsOneWidget,
      );
    },
  );
}
