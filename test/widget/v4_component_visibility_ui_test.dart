import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  Workspace workspace() => Workspace(
        projectId: 'project-1',
        draftId: 'draft-1',
        version: 1,
        projectName: 'Visibility Test',
        designTargets: const ['web'],
        sections: {
          'screens': [
            {'id': 'screen-1', 'name': 'Dashboard'},
          ],
          'components': [
            {
              'id': 'button-1',
              'screenId': 'screen-1',
              'type': 'button',
              'label': 'Delete Button',
              'text': 'Delete',
              'properties': {
                'enabled': true,
                'customProperty': 'preserve-me',
                'visibility': {
                  'mode': 'role',
                  'role': 'admin',
                },
              },
            },
          ],
        },
      );

  Future<void> openEditor(
    WidgetTester tester,
    Future<void> Function(String, dynamic) onSave,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: V4ComponentsStudio(
              workspace: workspace(),
              onSave: onSave,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit component'), findsOneWidget);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editing preserves role visibility and other properties',
    (tester) async {
      List<Map<String, dynamic>>? saved;

      await openEditor(tester, (section, data) async {
        expect(section, 'components');
        saved = (data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

      expect(
        find.byKey(const ValueKey('visibility-mode-selector')),
        findsOneWidget,
      );

      final roleField = find.widgetWithText(
        TextFormField,
        'Required User Role',
      );

      await tester.ensureVisible(roleField);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(roleField).controller!.text,
        'admin',
      );

      await save(tester);

      expect(saved, hasLength(1));

      final component = saved!.first;
      final props = Map<String, dynamic>.from(component['properties'] as Map);
      final visibility = Map<String, dynamic>.from(props['visibility'] as Map);

      expect(component['id'], 'button-1');
      expect(component['screenId'], 'screen-1');
      expect(props['enabled'], true);
      expect(props['customProperty'], 'preserve-me');
      expect(visibility['mode'], 'role');
      expect(visibility['role'], 'admin');
    },
  );

  testWidgets(
    'always visible removes previous role restriction',
    (tester) async {
      List<Map<String, dynamic>>? saved;

      await openEditor(tester, (_, data) async {
        saved = (data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });

      final mode = find.byKey(
        const ValueKey('visibility-mode-selector'),
      );

      await tester.ensureVisible(mode);
      await tester.pumpAndSettle();

      await tester.tap(mode);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Always visible').last);
      await tester.pumpAndSettle();

      await save(tester);

      expect(saved, hasLength(1));

      final props = Map<String, dynamic>.from(
        saved!.first['properties'] as Map,
      );

      expect(saved!.first['id'], 'button-1');
      expect(props.containsKey('visibility'), isFalse);
      expect(props['enabled'], true);
      expect(props['customProperty'], 'preserve-me');
    },
  );
}
