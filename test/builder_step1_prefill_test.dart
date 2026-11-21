import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/app/app.dart';

void main() {
  testWidgets(
    'Create Project details prefill Builder Step 1',
    (tester) async {
      await tester.binding.setSurfaceSize(
        const Size(1200, 900),
      );

      addTearDown(
        () => tester.binding.setSurfaceSize(null),
      );

      await tester.pumpWidget(const ReqvioraApp());

      await tester.tap(
        find.byKey(const Key('hub-create-project')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('project-name')),
        'Student Safety App',
      );

      await tester.enterText(
        find.byKey(const Key('project-description')),
        'Safety management system',
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

      await tester.tap(
        find.text('Open Input Studio'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('open-builder-step1')),
      );
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('builder-project-name')),
      );

      final descriptionField = tester.widget<TextFormField>(
        find.byKey(const Key('builder-project-description')),
      );

      expect(
        nameField.controller!.text,
        'Student Safety App',
      );

      expect(
        descriptionField.controller!.text,
        'Safety management system',
      );

      await tester.enterText(
        find.byKey(const Key('builder-project-name')),
        'Updated Safety App',
      );

      await tester.ensureVisible(
        find.byKey(const Key('builder-save-step1')),
      );

      await tester.tap(
        find.byKey(const Key('builder-save-step1')),
      );

      await tester.pump();

      expect(
        find.text('Step 1 details saved in draft'),
        findsOneWidget,
      );
    },
  );
}
