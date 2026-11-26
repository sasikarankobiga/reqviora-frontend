import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets('Step 07 preserves multiple component edits across Undo Redo', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = Workspace(
      projectId: 'project-multi',
      draftId: 'draft-multi',
      version: 1,
      projectName: 'REQVIORA Multi Component Test',
      designTargets: const ['web'],
      sections: {
        'interactions': <Map<String, dynamic>>[],
        'blueprint': {
          'screens': [
            {'screenId': 'home', 'name': 'Home'},
          ],
          'componentInstances': [
            {
              'componentInstanceId': 'title-1',
              'screenId': 'home',
              'type': 'text',
              'props': {'text': 'Welcome'},
            },
            {
              'componentInstanceId': 'title-2',
              'screenId': 'home',
              'type': 'text',
              'props': {'text': 'Description'},
            },
          ],
        },
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintStudio(workspace: workspace),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final first = find.byKey(const ValueKey('select-component-title-1'));
    final second = find.byKey(const ValueKey('select-component-title-2'));

    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('step07-edit-text-title-1')),
      'Updated Welcome',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(second);
    await tester.tap(second);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('step07-edit-text-title-2')),
      'Updated Description',
    );
    await tester.pumpAndSettle();

    expect(find.text('Updated Welcome'), findsWidgets);
    expect(find.text('Updated Description'), findsWidgets);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(find.text('Updated Welcome'), findsWidgets);
    expect(find.text('Description'), findsWidgets);

    final redo = find.byKey(const ValueKey('step07-redo-button'));

    await tester.ensureVisible(redo);
    await tester.tap(redo);
    await tester.pumpAndSettle();

    expect(find.text('Updated Welcome'), findsWidgets);
    expect(find.text('Updated Description'), findsWidgets);

    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
