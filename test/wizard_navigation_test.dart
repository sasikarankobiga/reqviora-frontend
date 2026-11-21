import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/app/app.dart';
import 'package:reqviora_frontend/features/wizard/domain/models/wizard_flow.dart';

void main() {
  testWidgets(
    'Builder navigates through all eight steps',
    (tester) async {
      await tester.binding.setSurfaceSize(
        const Size(1400, 950),
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
        'A safety management system',
      );

      await tester.ensureVisible(
        find.byKey(const Key('continue-project')),
      );

      await tester.tap(
        find.byKey(const Key('continue-project')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Open Input Studio'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('open-builder-step1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Step 1 of 8'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('builder-next-step1')),
      );

      await tester.tap(
        find.byKey(const Key('builder-next-step1')),
      );
      await tester.pumpAndSettle();

      for (var step = 2; step <= 8; step++) {
        final title = tester.widget<Text>(
          find.byKey(const Key('wizard-current-title')),
        );

        expect(
          title.data,
          WizardFlow.nameOf(step),
        );

        expect(
          find.text('Step $step of 8'),
          findsOneWidget,
        );

        expect(
          find.text(
            step == 2 ? '1 of 8 steps completed' : '2 of 8 steps completed',
          ),
          findsOneWidget,
        );

        if (step == 2) {
          final featureInput = find.byKey(
            const Key('step2-feature-input'),
          );

          await tester.ensureVisible(featureInput);
          await tester.enterText(featureInput, 'Authentication');

          final addFeature = find.byKey(
            const Key('step2-add-feature'),
          );

          await tester.ensureVisible(addFeature);
          await tester.tap(addFeature);
          await tester.pumpAndSettle();

          final screenInput = find.byKey(
            const Key('step2-screen-input'),
          );

          await tester.ensureVisible(screenInput);
          await tester.enterText(screenInput, 'Login Screen');

          final addScreen = find.byKey(
            const Key('step2-add-screen'),
          );

          await tester.ensureVisible(addScreen);
          await tester.tap(addScreen);
          await tester.pumpAndSettle();

          final mappingButton = find.byKey(
            const Key('step2-map'),
          );

          await tester.ensureVisible(mappingButton);
          await tester.tap(mappingButton);
          await tester.pumpAndSettle();
        }

        if (step < 8) {
          await tester.ensureVisible(
            find.byKey(const Key('wizard-next')),
          );

          await tester.tap(
            find.byKey(const Key('wizard-next')),
          );
          await tester.pumpAndSettle();
        }
      }

      expect(
        find.byKey(const Key('wizard-final-pending')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('wizard-back')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Step 7 of 8'),
        findsOneWidget,
      );
    },
  );
}
