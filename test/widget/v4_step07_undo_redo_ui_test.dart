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
        projectName: 'REQVIORA Test',
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
            ],
          },
        },
      );

  Future<void> openStudio(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    await tester.tap(
      find.byKey(const ValueKey('select-component-title-1')),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Undo and Redo restore property and preview', (tester) async {
    await openStudio(tester);

    final undo = find.byKey(const ValueKey('step07-undo-button'));
    final redo = find.byKey(const ValueKey('step07-redo-button'));
    final input = find.byKey(
      const ValueKey('step07-edit-text-title-1'),
    );

    expect(tester.widget<OutlinedButton>(undo).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(redo).onPressed, isNull);

    await tester.enterText(input, 'Hello REQVIORA');
    await tester.pumpAndSettle();

    expect(find.text('Hello REQVIORA'), findsWidgets);
    expect(tester.widget<OutlinedButton>(undo).onPressed, isNotNull);

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsWidgets);
    expect(tester.widget<TextFormField>(input).initialValue, 'Welcome');
    expect(tester.widget<OutlinedButton>(redo).onPressed, isNotNull);

    await tester.ensureVisible(redo);
    await tester.tap(redo);
    await tester.pumpAndSettle();

    expect(find.text('Hello REQVIORA'), findsWidgets);
    expect(
      tester.widget<TextFormField>(input).initialValue,
      'Hello REQVIORA',
    );
  });

  testWidgets('new edit after Undo disables Redo', (tester) async {
    await openStudio(tester);

    final undo = find.byKey(const ValueKey('step07-undo-button'));
    final redo = find.byKey(const ValueKey('step07-redo-button'));
    final input = find.byKey(
      const ValueKey('step07-edit-text-title-1'),
    );

    await tester.enterText(input, 'First change');
    await tester.pumpAndSettle();

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(tester.widget<OutlinedButton>(redo).onPressed, isNotNull);

    await tester.enterText(input, 'Second change');
    await tester.pumpAndSettle();

    expect(tester.widget<OutlinedButton>(redo).onPressed, isNull);
    expect(find.text('Second change'), findsWidgets);
  });
}
