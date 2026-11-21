
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reqviora_frontend/features/projects/presentation/pages/create_project_page.dart';

void main() {
  testWidgets(
    'Create Project form validates required fields',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreateProjectPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test 1: Page is displayed.
      expect(
        find.text('Start a New Project'),
        findsOneWidget,
      );

      // Test 2: Submit without filling fields.
      await tester.ensureVisible(
        find.byKey(const Key('create_project_button')),
      );

      await tester.tap(
        find.byKey(const Key('create_project_button')),
      );

      await tester.pump();

      // Test 3: Check required field errors.
      expect(
        find.text('Enter at least 3 characters'),
        findsOneWidget,
      );

      expect(
        find.text('Enter at least 10 characters'),
        findsOneWidget,
      );

      expect(
        find.text('Select a project type'),
        findsOneWidget,
      );

      expect(
        find.text('Target audience is required'),
        findsOneWidget,
      );
    },
  );
}
