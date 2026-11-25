import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  Workspace workspace() => Workspace(
    projectId: 'project-1',
    draftId: 'draft-1',
    version: 1,
    projectName: 'Design Studio Test',
    designTargets: ['web'],
    sections: {
      'screens': [
        {'id': 's1', 'name': 'Home'},
      ],
      'components': [
        {'id': 'c1', 'screenId': 's1', 'type': 'button', 'label': 'Continue'},
      ],
      'routes': [],
    },
  );

  Future<void> openStudio(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintStudio(workspace: workspace()),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await tester.tap(find.text('Generate Local Preview'));
    await tester.pumpAndSettle();
  }

  Future<void> selectComponent(WidgetTester tester) async {
    final item = find.byKey(const ValueKey('select-component-c1'));

    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Future<void> editLabel(WidgetTester tester) async {
    final field = find.byKey(const ValueKey('step07-edit-label-c1'));

    await tester.ensureVisible(field);
    await tester.enterText(field, 'Updated button');
    await tester.pumpAndSettle();
  }

  testWidgets('Preserves backend workflow controls', (tester) async {
    await openStudio(tester);

    expect(find.text('Generate & Save Blueprint'), findsOneWidget);
    expect(find.text('Safe AI Regeneration'), findsOneWidget);
    expect(find.text('Generate Local Preview'), findsOneWidget);
  });

  testWidgets('Generates an editable visual draft', (tester) async {
    await openStudio(tester);
    await generate(tester);

    expect(find.byKey(const ValueKey('select-component-c1')), findsOneWidget);

    expect(find.text('Save Visual Draft'), findsOneWidget);

    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);
  });

  testWidgets('Selects a component and edits its label', (tester) async {
    await openStudio(tester);
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    expect(find.text('Component Properties'), findsOneWidget);
    expect(find.text('Updated button'), findsWidgets);
  });

  testWidgets('Undo restores previous component label', (tester) async {
    await openStudio(tester);
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('step07-edit-label-c1')),
    );

    expect(field.initialValue, 'Continue');
  });

  testWidgets('Redo restores the edited label', (tester) async {
    await openStudio(tester);
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    final redo = find.byKey(const ValueKey('step07-redo-button'));

    await tester.ensureVisible(redo);
    await tester.tap(redo);
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('step07-edit-label-c1')),
    );

    expect(field.initialValue, 'Updated button');
  });

  testWidgets('Blocks AI generation during unsaved editing', (tester) async {
    await openStudio(tester);
    await generate(tester);

    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate & Save Blueprint'),
    );

    final regenerateButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Safe AI Regeneration'),
    );

    expect(generateButton.onPressed, isNull);
    expect(regenerateButton.onPressed, isNull);
  });
}
