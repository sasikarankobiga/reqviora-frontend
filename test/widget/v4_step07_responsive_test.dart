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
    projectName: 'REQVIORA Responsive Test',
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

  Future<void> verifyResponsiveEditing(
    WidgetTester tester,
    Size screenSize,
  ) async {
    await tester.binding.setSurfaceSize(screenSize);
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

    expect(find.text('Blueprint & UI Studio'), findsOneWidget);

    final select = find.byKey(const ValueKey('select-component-title-1'));

    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('step07-edit-text-title-1'));

    expect(input, findsOneWidget);

    await tester.ensureVisible(input);
    await tester.enterText(input, 'Responsive REQVIORA');
    await tester.pumpAndSettle();

    expect(find.text('Responsive REQVIORA'), findsWidgets);
    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsWidgets);

    final redo = find.byKey(const ValueKey('step07-redo-button'));

    await tester.ensureVisible(redo);
    await tester.tap(redo);
    await tester.pumpAndSettle();

    expect(find.text('Responsive REQVIORA'), findsWidgets);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Step 07 mobile component edit and Undo Redo', (tester) async {
    await verifyResponsiveEditing(tester, const Size(390, 844));
  });

  testWidgets('Step 07 tablet component edit and Undo Redo', (tester) async {
    await verifyResponsiveEditing(tester, const Size(768, 1024));
  });
}
