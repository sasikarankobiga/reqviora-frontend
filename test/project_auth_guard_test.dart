
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:reqviora_frontend/features/projects/presentation/pages/create_project_page.dart';

void main() {
  testWidgets(
    'Unauthenticated user cannot create a project',
    (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/projects/create',
        routes: [
          GoRoute(
            path: '/projects/create',
            builder: (context, state) =>
                const CreateProjectPage(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) =>
                const Scaffold(body: Text('Dashboard')),
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter valid project name.
      await tester.enterText(
        find.byKey(const Key('project_name')),
        'Student Management System',
      );

      // Enter valid project description.
      await tester.enterText(
        find.byKey(const Key('project_description')),
        'A web system for managing student records.',
      );

      // Enter target audience.
      await tester.enterText(
        find.byKey(const Key('target_audience')),
        'Students and teachers',
      );

      // Scroll to Project Type dropdown before tapping.
      final projectTypeFinder = find.byKey(
        const Key('project_type'),
      );

      await tester.ensureVisible(projectTypeFinder);
      await tester.pumpAndSettle();

      await tester.tap(projectTypeFinder);
      await tester.pumpAndSettle();

      // Select Web Application.
      final webApplicationFinder = find.text(
        'Web Application',
      ).last;

      await tester.tap(webApplicationFinder);
      await tester.pumpAndSettle();

      // Scroll to Continue button.
      final createButtonFinder = find.byKey(
        const Key('create_project_button'),
      );

      await tester.ensureVisible(createButtonFinder);
      await tester.pumpAndSettle();

      // Submit valid form without authentication.
      await tester.tap(createButtonFinder);
      await tester.pumpAndSettle();

      // Verify the correct Create Project authentication error.
      expect(
        find.text('Please sign in before creating a project.'),
        findsOneWidget,
      );

      // User must remain on Create Project page.
      expect(
        find.text('Start a New Project'),
        findsOneWidget,
      );

      // Project must not be created.
      expect(
        find.text('Project created successfully!'),
        findsNothing,
      );
    },
  );
}
