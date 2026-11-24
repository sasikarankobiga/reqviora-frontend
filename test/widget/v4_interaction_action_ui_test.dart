import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  Workspace createWorkspace() => Workspace(
        projectId: 'project-1',
        draftId: 'draft-1',
        version: 1,
        projectName: 'V4 Action Test',
        designTargets: const ['web'],
        sections: {
          'components': [
            {
              'id': 'button-1',
              'type': 'button',
              'label': 'Submit Button',
              'screenId': 'screen-1',
            },
            {
              'id': 'input-1',
              'type': 'input',
              'label': 'Email Input',
              'screenId': 'screen-1',
            },
          ],
          'screens': [
            {'id': 'screen-1', 'name': 'Home'},
            {'id': 'screen-2', 'name': 'Dashboard'},
          ],
          'interactions': <Map<String, dynamic>>[],
        },
      );

  Future<void> openEditor(
    WidgetTester tester,
    Future<void> Function(String, dynamic) onSave,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: V4InteractionsStudio(
              workspace: createWorkspace(),
              onSave: onSave,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }

  Finder dropdown(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == label,
      );

  Future<void> choose(
    WidgetTester tester,
    String label,
    String option,
  ) async {
    final field = dropdown(label);
    expect(field, findsOneWidget);

    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();

    final choice = find.text(option).last;
    expect(choice, findsOneWidget);
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Save').last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('button click navigates to selected screen', (tester) async {
    List<Map<String, dynamic>>? saved;

    await openEditor(tester, (section, data) async {
      expect(section, 'interactions');
      saved = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.enterText(
      find.byType(TextFormField).first,
      'Submit navigation',
    );

    await choose(tester, 'Source Component', 'Submit Button');
    await choose(tester, 'Trigger', 'onClick');
    await choose(tester, 'Destination Screen', 'Dashboard');

    await save(tester);

    expect(saved, hasLength(1));

    final rule = saved!.first;
    expect(rule['name'], 'Submit navigation');
    expect(rule['componentId'], 'button-1');
    expect(rule['trigger'], 'onClick');
    expect(rule['action'], 'navigate');
    expect(rule['targetScreenId'], 'screen-2');
  });

  testWidgets('button click shows configured message', (tester) async {
    List<Map<String, dynamic>>? saved;

    await openEditor(tester, (_, data) async {
      saved = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.enterText(
      find.byType(TextFormField).first,
      'Success message',
    );

    await choose(tester, 'Source Component', 'Submit Button');
    await choose(tester, 'Trigger', 'onClick');
    await choose(tester, 'Action', 'show-message');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Message text'),
      'Saved successfully',
    );

    await save(tester);

    expect(saved, hasLength(1));
    expect(saved!.first['action'], 'show-message');
    expect(saved!.first['message'], 'Saved successfully');
    expect(saved!.first.containsKey('targetScreenId'), isFalse);
  });

  testWidgets('input change configures loading state', (tester) async {
    List<Map<String, dynamic>>? saved;

    await openEditor(tester, (_, data) async {
      saved = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.enterText(
      find.byType(TextFormField).first,
      'Input loading',
    );

    await choose(tester, 'Source Component', 'Email Input');
    await choose(tester, 'Trigger', 'onChange');
    await choose(tester, 'Action', 'set-state');
    await choose(tester, 'Target UI State', 'loading');

    await save(tester);

    expect(saved, hasLength(1));
    expect(saved!.first['componentId'], 'input-1');
    expect(saved!.first['trigger'], 'onChange');
    expect(saved!.first['action'], 'set-state');
    expect(saved!.first['targetState'], 'loading');
    expect(saved!.first.containsKey('targetScreenId'), isFalse);
  });
}
