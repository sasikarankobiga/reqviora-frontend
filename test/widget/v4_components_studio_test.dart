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
    Future<void> Function(String, dynamic) onSave, {
    Workspace? workspace,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: V4ComponentsStudio(
              workspace: workspace ?? sampleWorkspace(),
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

  testWidgets('preserves existing component ID when editing', (tester) async {
    final workspace = Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
        ],
        'components': [
          {
            'id': 'component-123',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Old Submit',
            'text': 'Submit',
          },
        ],
      },
    );

    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit component'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated Submit',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));
    expect(savedItems!.first['id'], 'component-123');
    expect(savedItems!.first['label'], 'Updated Submit');
    expect(savedItems!.first['screenId'], 'screen-1');
    expect(savedItems!.first['type'], 'button');
  });

  testWidgets('keeps original component when save is not persisted',
      (tester) async {
    final workspace = Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
        ],
        'components': [
          {
            'id': 'component-123',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Old Submit',
            'text': 'Submit',
          },
        ],
      },
    );

    var saveCalls = 0;
    String? requestedLabel;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      saveCalls++;
      requestedLabel = (data as List).first['label'] as String;
      // Simulates a parent that handles a failed save without refresh.
    }, workspace: workspace);

    expect(find.text('Old Submit'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated Submit',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(requestedLabel, 'Updated Submit');

    expect(find.text('Old Submit'), findsOneWidget);
    expect(find.text('Updated Submit'), findsNothing);
  });

  testWidgets('removes component after confirmation', (tester) async {
    final workspace = Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
        ],
        'components': [
          {
            'id': 'component-123',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Submit',
            'text': 'Submit',
          },
        ],
      },
    );

    var saveCalls = 0;
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      saveCalls++;
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove this item?'), findsOneWidget);

    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(savedItems, isNotNull);
    expect(savedItems, isEmpty);

    // Original UI remains until workspace refresh.
    expect(find.byTooltip('Edit'), findsOneWidget);
  });

  testWidgets('keeps component when removal is cancelled', (tester) async {
    final workspace = Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
        ],
        'components': [
          {
            'id': 'component-123',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Submit',
            'text': 'Submit',
          },
        ],
      },
    );

    var saveCalls = 0;

    await openStudio(tester, (section, data) async {
      saveCalls++;
    }, workspace: workspace);

    expect(find.text('Submit'), findsWidgets);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove this item?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Remove this item?'), findsNothing);
    expect(find.text('Submit'), findsWidgets);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(saveCalls, 0);
  });

  testWidgets('keeps original component when edit is cancelled',
      (tester) async {
    final workspace = Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
        ],
        'components': [
          {
            'id': 'component-123',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Original Submit',
            'text': 'Submit',
          },
        ],
      },
    );

    var saveCalls = 0;

    await openStudio(tester, (section, data) async {
      saveCalls++;
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit component'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Cancelled Change',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Edit component'), findsNothing);
    expect(find.text('Original Submit'), findsOneWidget);
    expect(find.text('Cancelled Change'), findsNothing);
    expect(saveCalls, 0);
  });

  testWidgets('does not save when adding a component is cancelled',
      (tester) async {
    var saveCalls = 0;

    await openStudio(tester, (section, data) async {
      saveCalls++;
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add component'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Temporary Component',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Add component'), findsNothing);
    expect(find.text('Temporary Component'), findsNothing);
    expect(saveCalls, 0);
  });

  testWidgets('rejects empty component label', (tester) async {
    var saveCalls = 0;

    await openStudio(tester, (section, data) async {
      saveCalls++;
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Choose a valid screen so the label is the only invalid field.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      '   ',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.text('Component label is required'), findsWidgets);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('shows screen validation when no screen is selected',
      (tester) async {
    var saveCalls = 0;

    await openStudio(tester, (section, data) async {
      saveCalls++;
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Submit Button',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.text('Select Screen'), findsWidgets);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('saves selected button component type', (tester) async {
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Select screen.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    // Select component type.
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('button').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Submit Button',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));
    expect(savedItems!.first['type'], 'button');
    expect(savedItems!.first['label'], 'Submit Button');
    expect(savedItems!.first['screenId'], 'screen-1');
  });
}
