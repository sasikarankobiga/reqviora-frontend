import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  Workspace workspace([
    Map<String, dynamic>? existing,
  ]) {
    return Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': <Map<String, dynamic>>[],
        'interactions': [
          if (existing != null) existing,
        ],
      },
    );
  }

  Future<void> openStudio(
    WidgetTester tester,
    Workspace data,
    Future<void> Function(String, dynamic) onSave,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: V4InteractionsStudio(
              workspace: data,
              onSave: onSave,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens Step 06 interaction editor', (tester) async {
    await openStudio(tester, workspace(), (_, _) async {});

    expect(find.text('Interaction & state rules'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add interaction'), findsOneWidget);
    expect(find.text('Rule name'), findsOneWidget);
    expect(find.text('UI State'), findsOneWidget);
    expect(
      find.text('Behavior / validation / recovery'),
      findsOneWidget,
    );
  });

  testWidgets('requires a rule name before save', (tester) async {
    var saveCalls = 0;

    await openStudio(tester, workspace(), (_, _) async {
      saveCalls++;
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.text('Add interaction'), findsOneWidget);
  });

  testWidgets('saves an error state rule', (tester) async {
    List<Map<String, dynamic>>? saved;

    await openStudio(tester, workspace(), (section, data) async {
      expect(section, 'interactions');
      saved = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Form Validation',
    );

    final stateDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'UI State',
    );

    await tester.tap(stateDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('error').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).last,
      'Display validation errors and allow retry',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved, hasLength(1));
    expect(saved!.first['id'], isNotEmpty);
    expect(saved!.first['name'], 'Form Validation');
    expect(saved!.first['state'], 'error');
    expect(
      saved!.first['description'],
      'Display validation errors and allow retry',
    );
  });

  testWidgets('edits rule while preserving its ID', (tester) async {
    List<Map<String, dynamic>>? saved;

    await openStudio(
      tester,
      workspace({
        'id': 'interaction-123',
        'name': 'Loading Rule',
        'state': 'loading',
        'description': 'Show spinner',
      }),
      (section, data) async {
        expect(section, 'interactions');
        saved = (data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      },
    );

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated Loading Rule',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved!.first['id'], 'interaction-123');
    expect(saved!.first['name'], 'Updated Loading Rule');
    expect(saved!.first['state'], 'loading');
    expect(saved!.first['description'], 'Show spinner');
  });
}
