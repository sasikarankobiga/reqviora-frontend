import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  Workspace sampleWorkspace() {
    return Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
        ],
        'components': <Map<String, dynamic>>[],
      },
    );
  }

  Future<void> openStudio(
    WidgetTester tester,
    Future<void> Function(String, dynamic) onSave,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: V4ComponentsStudio(
              workspace: sampleWorkspace(),
              onSave: onSave,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens the original Add Component dialog', (tester) async {
    await openStudio(tester, (_, __) async {});

    expect(find.text('Components Studio'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add component'), findsOneWidget);
    expect(find.text('Component label'), findsOneWidget);
    expect(find.text('Component type'), findsOneWidget);
  });

  testWidgets('prevents saving without a screen', (tester) async {
    var saveCalls = 0;

    await openStudio(tester, (_, __) async {
      saveCalls++;
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Submit',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.text('Select Screen'), findsWidgets);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('saves a valid component with a unique ID', (tester) async {
    String? savedSection;
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      savedSection = section;
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byType(DropdownButtonFormField<String>).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Submit',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedSection, 'components');
    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));
    expect(savedItems!.first['screenId'], 'screen-1');
    expect(savedItems!.first['type'], 'text');
    expect(savedItems!.first['label'], 'Submit');
    expect((savedItems!.first['id'] as String).isNotEmpty, isTrue);
  });
}
