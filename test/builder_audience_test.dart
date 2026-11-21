import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/projects/domain/models/project_draft.dart';
import 'package:reqviora_frontend/features/wizard/domain/models/wizard_flow.dart';
import 'package:reqviora_frontend/features/wizard/presentation/pages/builder_step1_page.dart';

void main() {
  testWidgets('Step 1 saves audience details in draft', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final draft = ProjectDraft(
      name: 'Student Safety App',
      description: 'Safety management system',
    );

    final flow = WizardFlow(draft: draft);

    await tester.pumpWidget(
      MaterialApp(
        home: BuilderStep1Page(
          projectDraft: draft,
          flow: flow,
        ),
      ),
    );

    final audience = find.byKey(
      const Key('builder-target-audience'),
    );

    final goal = find.byKey(
      const Key('builder-primary-user-goal'),
    );

    await tester.ensureVisible(audience);
    await tester.enterText(audience, 'Students');

    await tester.ensureVisible(goal);
    await tester.enterText(goal, 'Receive safety alerts');

    final save = find.byKey(
      const Key('builder-save-step1'),
    );

    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();

    expect(draft.targetAudience, 'Students');
    expect(draft.primaryUserGoal, 'Receive safety alerts');
  });
}
