import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets('Screen Editor saves normalized access roles', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final workspace = Workspace(
      projectId: 'project-test',
      draftId: 'draft-test',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: const {
        'features': <Map<String, dynamic>>[],
        'screens': <Map<String, dynamic>>[],
      },
    );

    String? savedSection;
    dynamic savedData;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: V4ScreensStudio(
              workspace: workspace,
              onSave: (section, data) async {
                savedSection = section;
                savedData = data;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add screen'), findsOneWidget);

    final nameField = find.widgetWithText(TextFormField, 'Screen name');
    await tester.enterText(nameField, 'Dashboard');

    final roleField = find.widgetWithText(
      TextFormField,
      'Access roles (comma-separated)',
    );
    await tester.ensureVisible(roleField);
    await tester.enterText(roleField, ' Admin, Manager, Admin, , User ');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedSection, 'screens');
    expect(savedData, isA<List>());

    final screens = savedData as List;
    expect(screens, hasLength(1));

    final screen = screens.single as Map;
    expect(screen['name'], 'Dashboard');
    expect(screen['accessRoles'], ['Admin', 'Manager', 'User']);
    expect(screen['featureIds'], isEmpty);
    expect(tester.takeException(), isNull);
  });
}
