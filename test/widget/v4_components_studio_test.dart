import 'dart:async';
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
    await openStudio(tester, (_, _) async {});

    expect(find.text('Components Studio'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add component'), findsOneWidget);
    expect(find.text('Component label'), findsOneWidget);
    expect(find.text('Component type'), findsOneWidget);
  });

  testWidgets('prevents saving without a screen', (tester) async {
    var saveCalls = 0;

    await openStudio(tester, (_, _) async {
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
    await tester.tap(find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Component type',
    ));
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

  testWidgets('saves component display text', (tester) async {
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Select a valid screen.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);

    await tester.enterText(fields.first, 'Welcome Message');
    await tester.enterText(fields.last, 'Welcome to REQVIORA');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));
    expect(savedItems!.first['label'], 'Welcome Message');
    expect(savedItems!.first['text'], 'Welcome to REQVIORA');
    expect(savedItems!.first['screenId'], 'screen-1');
  });

  testWidgets('updates component type while preserving ID', (tester) async {
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
            'text': 'Submit Form',
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

    // Change existing button component to input.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Component type',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('input').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));

    // Existing component identity must remain unchanged.
    expect(savedItems!.first['id'], 'component-123');
    expect(savedItems!.first['type'], 'input');
    expect(savedItems!.first['label'], 'Submit');
    expect(savedItems!.first['screenId'], 'screen-1');
    expect(savedItems!.first['text'], 'Submit Form');
  });

  testWidgets('updates component display text while preserving ID',
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
            'type': 'text',
            'label': 'Welcome Message',
            'text': 'Old Welcome Text',
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
      find.byType(TextFormField).last,
      'Updated Welcome to REQVIORA',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));
    expect(savedItems!.first['id'], 'component-123');
    expect(savedItems!.first['label'], 'Welcome Message');
    expect(savedItems!.first['text'], 'Updated Welcome to REQVIORA');
    expect(savedItems!.first['screenId'], 'screen-1');
    expect(savedItems!.first['type'], 'text');
  });

  testWidgets('reassigns component screen while preserving ID', (tester) async {
    final workspace = Workspace(
      projectId: 'project-1',
      draftId: 'draft-1',
      version: 1,
      projectName: 'Test Project',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'screen-1', 'name': 'Dashboard'},
          {'id': 'screen-2', 'name': 'Settings'},
        ],
        'components': [
          {
            'id': 'component-123',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Save Changes',
            'text': 'Save',
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

    // Change the component's assigned screen.
    await tester.tap(
      find.byType(DropdownButtonFormField<String>).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));
    expect(savedItems!.first['id'], 'component-123');
    expect(savedItems!.first['screenId'], 'screen-2');
    expect(savedItems!.first['type'], 'button');
    expect(savedItems!.first['label'], 'Save Changes');
    expect(savedItems!.first['text'], 'Save');
  });

  testWidgets(
    'saves button enabled property while preserving existing properties',
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
              'label': 'Submit',
              'text': 'Submit Form',
              'properties': {
                'enabled': true,
                'variant': 'primary',
              },
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

      final enabledSwitch = find.byType(SwitchListTile);

      expect(enabledSwitch, findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(enabledSwitch).value,
        isTrue,
      );

      await tester.ensureVisible(enabledSwitch);
      await tester.tap(enabledSwitch);
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(enabledSwitch).value,
        isFalse,
      );

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(savedItems, isNotNull);
      expect(savedItems, hasLength(1));

      final saved = savedItems!.single;
      final properties = Map<String, dynamic>.from(saved['properties'] as Map);

      expect(saved['id'], 'component-123');
      expect(saved['type'], 'button');
      expect(saved['label'], 'Submit');
      expect(saved['screenId'], 'screen-1');
      expect(properties['enabled'], isFalse);
      expect(properties['variant'], 'primary');
    },
  );

  testWidgets('new button saves enabled true by default', (tester) async {
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Component type',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('button').last);
    await tester.pumpAndSettle();

    final enabledSwitch = find.byType(SwitchListTile);

    expect(enabledSwitch, findsOneWidget);
    expect(tester.widget<SwitchListTile>(enabledSwitch).value, isTrue);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Submit Button',
    );

    await tester.enterText(
      find.byType(TextFormField).last,
      'Submit',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));

    final saved = savedItems!.single;
    final properties = Map<String, dynamic>.from(saved['properties'] as Map);

    expect(saved['id'], isNotEmpty);
    expect(saved['screenId'], 'screen-1');
    expect(saved['type'], 'button');
    expect(saved['label'], 'Submit Button');
    expect(saved['text'], 'Submit');
    expect(properties['enabled'], isTrue);
  });

  testWidgets(
    'updates text font size while preserving existing properties',
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
              'id': 'component-text-123',
              'screenId': 'screen-1',
              'type': 'text',
              'label': 'Welcome Message',
              'text': 'Welcome to REQVIORA',
              'properties': {
                'fontSize': 24,
                'color': '#663399',
              },
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

      final fontSlider = find.byType(Slider);

      expect(fontSlider, findsOneWidget);
      expect(
        tester.widget<Slider>(fontSlider).value,
        24,
      );

      // Update the font-size slider.
      tester.widget<Slider>(fontSlider).onChanged!(32);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Slider>(fontSlider).value,
        32,
      );

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(savedItems, isNotNull);
      expect(savedItems, hasLength(1));

      final saved = savedItems!.single;
      final properties = Map<String, dynamic>.from(saved['properties'] as Map);

      expect(saved['id'], 'component-text-123');
      expect(saved['screenId'], 'screen-1');
      expect(saved['type'], 'text');
      expect(saved['label'], 'Welcome Message');
      expect(saved['text'], 'Welcome to REQVIORA');
      expect(properties['fontSize'], 32);
      expect(properties['color'], '#663399');
    },
  );

  testWidgets(
    'updates input placeholder while preserving properties',
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
              'id': 'component-input-123',
              'screenId': 'screen-1',
              'type': 'input',
              'label': 'Email Address',
              'text': 'Email',
              'properties': {
                'placeholder': 'Enter your email',
                'required': true,
              },
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
      expect(find.byType(TextFormField), findsNWidgets(3));

      final placeholderField = find.byType(TextFormField).last;

      expect(
        tester.widget<TextFormField>(placeholderField).controller!.text,
        'Enter your email',
      );

      await tester.enterText(
        placeholderField,
        'Enter your new email address',
      );

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(savedItems, isNotNull);
      expect(savedItems, hasLength(1));

      final saved = savedItems!.single;
      final properties = Map<String, dynamic>.from(saved['properties'] as Map);

      expect(saved['id'], 'component-input-123');
      expect(saved['screenId'], 'screen-1');
      expect(saved['type'], 'input');
      expect(saved['label'], 'Email Address');
      expect(saved['text'], 'Email');

      expect(
        properties['placeholder'],
        'Enter your new email address',
      );
      expect(properties['required'], isTrue);
    },
  );

  testWidgets('new input saves default placeholder', (tester) async {
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      savedItems = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add component'), findsOneWidget);

    // Select the existing Dashboard screen.
    await tester.tap(
      find.byType(DropdownButtonFormField<String>).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();

    // Select the Input component type.
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Component type',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('input').last);
    await tester.pumpAndSettle();

    // Verify the automatically populated placeholder.
    final placeholderField = find.byType(TextFormField).last;

    expect(
      tester.widget<TextFormField>(placeholderField).controller!.text,
      'Enter text',
    );

    // Provide the required component label and display text.
    await tester.enterText(
      find.byType(TextFormField).first,
      'Email Address',
    );

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Email',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));

    final saved = savedItems!.single;
    final properties = Map<String, dynamic>.from(saved['properties'] as Map);

    expect(saved['id'], isA<String>());
    expect((saved['id'] as String).isNotEmpty, isTrue);
    expect(saved['screenId'], 'screen-1');
    expect(saved['type'], 'input');
    expect(saved['label'], 'Email Address');
    expect(saved['text'], 'Email');
    expect(properties['placeholder'], 'Enter text');
  });

  testWidgets(
    'updates input required property while preserving placeholder',
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
              'id': 'component-input-required-1',
              'screenId': 'screen-1',
              'type': 'input',
              'label': 'Email',
              'text': 'Email address',
              'properties': {
                'placeholder': 'Enter your email',
                'required': true,
                'variant': 'outlined',
              },
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

      final requiredSwitch = find.widgetWithText(
        SwitchListTile,
        'Required',
      );

      expect(requiredSwitch, findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(requiredSwitch).value,
        isTrue,
      );

      await tester.ensureVisible(requiredSwitch);
      await tester.pumpAndSettle();

      await tester.tap(requiredSwitch);
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(requiredSwitch).value,
        isFalse,
      );

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(savedItems, isNotNull);
      expect(savedItems, hasLength(1));

      final saved = savedItems!.single;
      final properties = Map<String, dynamic>.from(saved['properties'] as Map);

      expect(saved['id'], 'component-input-required-1');
      expect(saved['screenId'], 'screen-1');
      expect(saved['type'], 'input');
      expect(saved['label'], 'Email');
      expect(saved['text'], 'Email address');

      expect(properties['required'], isFalse);
      expect(properties['placeholder'], 'Enter your email');
      expect(properties['variant'], 'outlined');
    },
  );

  testWidgets('new input defaults to optional', (tester) async {
    List<Map<String, dynamic>>? savedItems;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
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

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Component type',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('input').last);
    await tester.pumpAndSettle();

    final requiredSwitch = find.widgetWithText(
      SwitchListTile,
      'Required',
    );

    expect(requiredSwitch, findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(requiredSwitch).value,
      isFalse,
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'Phone Number',
    );

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Phone',
    );

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(savedItems, isNotNull);
    expect(savedItems, hasLength(1));

    final saved = savedItems!.single;
    final properties = Map<String, dynamic>.from(saved['properties'] as Map);

    expect(saved['screenId'], 'screen-1');
    expect(saved['type'], 'input');
    expect(saved['label'], 'Phone Number');
    expect(properties['required'], isFalse);
    expect(properties['placeholder'], 'Enter text');
  });

  testWidgets(
    'updates card elevation while preserving properties',
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
              'id': 'component-card-123',
              'screenId': 'screen-1',
              'type': 'card',
              'label': 'Profile Card',
              'text': 'User Profile',
              'properties': {
                'elevation': 4,
                'variant': 'outlined',
                'borderRadius': 12,
              },
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

      final elevationSlider = find.byWidgetPredicate(
        (widget) => widget is Slider && widget.min == 0 && widget.max == 24,
      );

      expect(elevationSlider, findsOneWidget);

      expect(
        tester.widget<Slider>(elevationSlider).value,
        4,
      );

      // Change elevation through the slider callback.
      tester.widget<Slider>(elevationSlider).onChanged!(12);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Slider>(elevationSlider).value,
        12,
      );

      await tester.ensureVisible(find.text('Save').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(savedItems, isNotNull);
      expect(savedItems, hasLength(1));

      final saved = savedItems!.single;
      final properties = Map<String, dynamic>.from(saved['properties'] as Map);

      expect(saved['id'], 'component-card-123');
      expect(saved['screenId'], 'screen-1');
      expect(saved['type'], 'card');
      expect(saved['label'], 'Profile Card');
      expect(saved['text'], 'User Profile');

      expect(properties['elevation'], 12);
      expect(properties['variant'], 'outlined');
      expect(properties['borderRadius'], 12);
    },
  );

  testWidgets(
    'reorders components and preserves their data',
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
              'id': 'component-a',
              'screenId': 'screen-1',
              'type': 'text',
              'label': 'First Component',
              'text': 'First',
              'properties': {'fontSize': 18},
            },
            {
              'id': 'component-b',
              'screenId': 'screen-1',
              'type': 'button',
              'label': 'Second Component',
              'text': 'Second',
              'properties': {'enabled': true},
            },
            {
              'id': 'component-c',
              'screenId': 'screen-1',
              'type': 'card',
              'label': 'Third Component',
              'text': 'Third',
              'properties': {'elevation': 4},
            },
          ],
        },
      );

      List<Map<String, dynamic>>? savedItems;
      var saveCalls = 0;

      await openStudio(tester, (section, data) async {
        expect(section, 'components');
        saveCalls++;
        savedItems = (data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }, workspace: workspace);

      final reorderList = find.byType(ReorderableListView);

      expect(reorderList, findsOneWidget);

      final list = tester.widget<ReorderableListView>(reorderList);

      // Move first component to the final position.
      list.onReorderItem!(0, 2);
      await tester.pumpAndSettle();

      expect(saveCalls, 1);
      expect(savedItems, isNotNull);
      expect(savedItems, hasLength(3));

      expect(
        savedItems!.map((item) => item['id']).toList(),
        ['component-b', 'component-c', 'component-a'],
      );

      // Component identities and mappings must stay unchanged.
      expect(savedItems![0]['screenId'], 'screen-1');
      expect(savedItems![1]['screenId'], 'screen-1');
      expect(savedItems![2]['screenId'], 'screen-1');

      expect(
        (savedItems![0]['properties'] as Map)['enabled'],
        isTrue,
      );
      expect(
        (savedItems![1]['properties'] as Map)['elevation'],
        4,
      );
      expect(
        (savedItems![2]['properties'] as Map)['fontSize'],
        18,
      );

      // Confirm the visible list also uses the saved order.
      final visibleLabels = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data)
          .toList();

      expect(
        visibleLabels,
        ['Second Component', 'Third Component', 'First Component'],
      );
    },
  );

  testWidgets(
    'keeps component order until reorder save completes',
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
              'id': 'component-a',
              'screenId': 'screen-1',
              'type': 'text',
              'label': 'First',
              'properties': {'fontSize': 18},
            },
            {
              'id': 'component-b',
              'screenId': 'screen-1',
              'type': 'button',
              'label': 'Second',
              'properties': {'enabled': true},
            },
          ],
        },
      );

      final saveCompleter = Completer<void>();
      var saveCalls = 0;

      await openStudio(tester, (section, data) async {
        expect(section, 'components');
        saveCalls++;

        final next = (data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        expect(
          next.map((item) => item['id']).toList(),
          ['component-b', 'component-a'],
        );

        await saveCompleter.future;
      }, workspace: workspace);

      List<String?> visibleOrder() => tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data)
          .toList();

      expect(visibleOrder(), ['First', 'Second']);

      final reorderList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );

      reorderList.onReorderItem!(0, 1);
      await tester.pump();

      expect(saveCalls, 1);
      expect(visibleOrder(), ['First', 'Second']);

      saveCompleter.complete();
      await tester.pumpAndSettle();

      expect(visibleOrder(), ['Second', 'First']);
    },
  );

  for (final type in ['card', 'container', 'section']) {
    testWidgets(
      '$type preserves data when editing layout padding',
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
                'id': 'component-layout-123',
                'screenId': 'screen-1',
                'type': type,
                'label': 'Layout Component',
                'text': 'Original Content',
                'properties': {
                  'padding': 8,
                  'customToken': 'preserve-me',
                  if (type == 'card') 'elevation': 4,
                },
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

        final paddingSlider = find.byWidgetPredicate(
          (widget) => widget is Slider && widget.min == 0 && widget.max == 64,
        );

        expect(paddingSlider, findsOneWidget);

        expect(
          tester.widget<Slider>(paddingSlider).value,
          8,
        );

        tester.widget<Slider>(paddingSlider).onChanged!(32);
        await tester.pumpAndSettle();

        expect(
          tester.widget<Slider>(paddingSlider).value,
          32,
        );

        await tester.ensureVisible(find.text('Save').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save').last);
        await tester.pumpAndSettle();

        expect(savedItems, isNotNull);
        expect(savedItems, hasLength(1));

        final saved = savedItems!.single;
        final properties =
            Map<String, dynamic>.from(saved['properties'] as Map);

        expect(saved['id'], 'component-layout-123');
        expect(saved['screenId'], 'screen-1');
        expect(saved['type'], type);
        expect(saved['label'], 'Layout Component');
        expect(saved['text'], 'Original Content');

        expect(properties['padding'], 32);
        expect(properties['customToken'], 'preserve-me');

        if (type == 'card') {
          expect(properties['elevation'], 4);
        }
      },
    );
  }

  for (final type in ['image', 'header', 'list', 'table']) {
    testWidgets(
      '$type preserves advanced inspector properties on edit',
      (tester) async {
        final initialProperties = <String, dynamic>{
          'customToken': 'preserve-me',
          if (type == 'image') ...{
            'src': 'https://example.com/old.png',
            'alt': 'Old image',
          },
          if (type == 'header') 'alignment': 'left',
          if (type == 'list') 'dense': false,
          if (type == 'table') 'stripedRows': false,
        };

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
                'id': 'component-advanced-123',
                'screenId': 'screen-1',
                'type': type,
                'label': 'Advanced Component',
                'text': 'Original Content',
                'properties': initialProperties,
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

        if (type == 'image') {
          final sourceField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Image URL',
          );

          final altField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.labelText == 'Alt text',
          );

          expect(sourceField, findsOneWidget);
          expect(altField, findsOneWidget);

          await tester.enterText(
            sourceField,
            'https://example.com/new.png',
          );
          await tester.enterText(altField, 'New accessible image');
        }

        if (type == 'header') {
          final alignmentField = find.byWidgetPredicate(
            (widget) =>
                widget is DropdownButtonFormField<String> &&
                widget.decoration.labelText == 'Header alignment',
          );

          expect(alignmentField, findsOneWidget);
          await tester.ensureVisible(alignmentField);
          await tester.tap(alignmentField);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Right').last);
          await tester.pumpAndSettle();
        }

        if (type == 'list' || type == 'table') {
          final title = type == 'list' ? 'Dense layout' : 'Striped rows';

          final toggle = find.widgetWithText(SwitchListTile, title);
          expect(toggle, findsOneWidget);

          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }

        final saveButton = find.text('Save').last;
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(savedItems, isNotNull);
        expect(savedItems, hasLength(1));

        final saved = savedItems!.single;
        final properties =
            Map<String, dynamic>.from(saved['properties'] as Map);

        expect(saved['id'], 'component-advanced-123');
        expect(saved['screenId'], 'screen-1');
        expect(saved['type'], type);
        expect(saved['label'], 'Advanced Component');
        expect(saved['text'], 'Original Content');
        expect(properties['customToken'], 'preserve-me');

        if (type == 'image') {
          expect(properties['src'], 'https://example.com/new.png');
          expect(properties['alt'], 'New accessible image');
        }

        if (type == 'header') {
          expect(properties['alignment'], 'right');
        }

        if (type == 'list') {
          expect(properties['dense'], true);
        }

        if (type == 'table') {
          expect(properties['stripedRows'], true);
        }
      },
    );
  }

  testWidgets('V4 reuse creates a separate component on another screen',
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
          {'id': 'screen-2', 'name': 'Settings'},
        ],
        'components': [
          {
            'id': 'original-card',
            'screenId': 'screen-1',
            'type': 'card',
            'label': 'Profile Card',
            'text': 'Profile details',
            'properties': {'padding': 16, 'elevation': 4},
          },
        ],
      },
    );

    List<Map<String, dynamic>>? saved;

    await openStudio(tester, (section, data) async {
      expect(section, 'components');
      saved = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Reuse'));
    await tester.pumpAndSettle();

    expect(find.text('Reuse component on screen'), findsOneWidget);

    final screenDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Target screen',
    );

    await tester.tap(screenDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reuse').last);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved, hasLength(2));

    final original = saved!.first;
    final reused = saved!.last;

    expect(original['id'], 'original-card');
    expect(original['screenId'], 'screen-1');
    expect(reused['id'], isNot('original-card'));
    expect(reused['screenId'], 'screen-2');
    expect(reused['templateSourceId'], 'original-card');
    expect(reused['label'], 'Profile Card');
    expect(reused['properties'], original['properties']);
  });

  testWidgets('V4 parent selector saves valid nested component',
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
            'id': 'parent-card',
            'screenId': 'screen-1',
            'type': 'card',
            'label': 'Parent Card',
            'text': 'Container content',
          },
          {
            'id': 'child-text',
            'screenId': 'screen-1',
            'type': 'text',
            'label': 'Child Text',
            'text': 'Nested text',
          },
        ],
      },
    );

    List<Map<String, dynamic>>? saved;

    await openStudio(tester, (section, data) async {
      saved = (data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Edit').last);
    await tester.pumpAndSettle();

    final parentDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Parent component',
    );

    await tester.ensureVisible(parentDropdown);
    await tester.tap(parentDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Parent Card').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save').last);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved, hasLength(2));
    expect(saved!.last['id'], 'child-text');
    expect(saved!.last['parentComponentId'], 'parent-card');
    expect(saved!.last['screenId'], 'screen-1');
    expect(saved!.first['id'], 'parent-card');
  });

  testWidgets('V4 prevents circular nesting before saving', (tester) async {
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
            'id': 'card-a',
            'screenId': 'screen-1',
            'type': 'card',
            'label': 'Card A',
            'parentComponentId': 'card-b',
          },
          {
            'id': 'card-b',
            'screenId': 'screen-1',
            'type': 'card',
            'label': 'Card B',
          },
        ],
      },
    );

    var saveCalls = 0;

    await openStudio(tester, (_, __) async {
      saveCalls++;
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Edit').last);
    await tester.pumpAndSettle();

    final parentDropdown = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Parent component',
    );

    await tester.ensureVisible(parentDropdown);
    await tester.tap(parentDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Card A').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save').last);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.textContaining('Circular component hierarchy'), findsWidgets);
  });

  testWidgets('V4 protects a parent with children from deletion',
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
            'id': 'parent-card',
            'screenId': 'screen-1',
            'type': 'card',
            'label': 'Parent Card',
          },
          {
            'id': 'child-text',
            'screenId': 'screen-1',
            'type': 'text',
            'label': 'Child Text',
            'parentComponentId': 'parent-card',
          },
        ],
      },
    );

    var saveCalls = 0;

    await openStudio(tester, (_, __) async {
      saveCalls++;
    }, workspace: workspace);

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();

    expect(find.text('Remove this item?'), findsOneWidget);

    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(
      find.text('Remove or reassign child components first'),
      findsWidgets,
    );
  });
}
