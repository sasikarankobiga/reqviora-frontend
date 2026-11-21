import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/app/app.dart';

void main() {
  testWidgets(
    'Create Project data passes to Overview and Input Studio',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(
        const Size(1200, 900),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ReqvioraApp());

      expect(
        find.text('YOUR IDEAS, IN MOTION'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('hub-create-project')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Create a New Project'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('project-name')),
        'Student Safety App',
      );

      await tester.enterText(
        find.byKey(const Key('project-description')),
        'A web-based safety management system.',
      );

      await tester.ensureVisible(
        find.byKey(const Key('continue-project')),
      );

      await tester.tap(
        find.byKey(const Key('continue-project')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Student Safety App'),
        findsOneWidget,
      );

      expect(
        find.text('A web-based safety management system.'),
        findsOneWidget,
      );

      await tester.tap(
        find.text('Open Input Studio'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Input Studio'),
        findsWidgets,
      );
    },
  );
}
