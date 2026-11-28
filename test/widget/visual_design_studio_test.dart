import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/application/workspace_providers.dart';
import 'package:reqviora_frontend/features/workspace/data/workspace_repository.dart';

import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

class RecordingWorkspaceRepository extends WorkspaceRepository {
  RecordingWorkspaceRepository(super.api);

  int saves = 0;
  int? savedFromVersion;
  String? savedSection;
  dynamic savedData;

  @override
  Future<int> save(
    String projectId,
    String section,
    int version,
    dynamic data, {
    Object? expectedSectionData,
  }) async {
    saves++;
    savedFromVersion = version;
    savedSection = section;
    savedData = data;
    return version + 1;
  }
}

void main() {
  Workspace workspace() => Workspace(
    projectId: 'project-1',
    draftId: 'draft-1',
    version: 1,
    projectName: 'Design Studio Test',
    designTargets: ['web'],
    sections: {
      'screens': [
        {'id': 's1', 'name': 'Home'},
      ],
      'components': [
        {'id': 'c1', 'screenId': 's1', 'type': 'button', 'label': 'Continue'},
      ],
      'routes': [],
    },
  );

  Future<void> openStudio(WidgetTester tester) async {
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
  }

  Future<void> generate(WidgetTester tester) async {
    await tester.tap(find.text('Generate Local Preview'));
    await tester.pumpAndSettle();
  }

  Future<void> selectComponent(WidgetTester tester) async {
    final item = find.byKey(const ValueKey('select-component-c1'));

    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Future<void> editLabel(WidgetTester tester) async {
    final field = find.byKey(const ValueKey('step07-edit-label-c1'));

    await tester.ensureVisible(field);
    await tester.enterText(field, 'Updated button');
    await tester.pumpAndSettle();
  }

  testWidgets('Autosave persists the visual draft and retains undo history', (
    tester,
  ) async {
    final api = ApiClient(
      MockClient((request) async {
        return http.Response('Unexpected network request', 500);
      }),
    );

    addTearDown(api.dispose);

    final repository = RecordingWorkspaceRepository(api);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workspaceRepositoryProvider.overrideWithValue(repository)],
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
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    final toggle = find.byKey(const ValueKey('step07-autosave-toggle'));

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();

    expect(repository.saves, 0);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(repository.saves, 1);
    expect(repository.savedFromVersion, 1);
    expect(repository.savedSection, 'visualEditorDraft');
    expect(repository.savedData, isA<Map>());
    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsNothing);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Discard restores the saved visual draft state', (tester) async {
    await openStudio(tester);
    await generate(tester);

    final discard = find.byKey(const ValueKey('step07-discard-button'));

    await tester.ensureVisible(discard);
    await tester.tap(discard);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsNothing);

    expect(find.text('Save Visual Draft'), findsNothing);
  });

  testWidgets('Preserves backend workflow controls', (tester) async {
    await openStudio(tester);

    expect(find.text('Generate & Save Blueprint'), findsOneWidget);
    expect(find.text('Safe AI Regeneration'), findsOneWidget);
    expect(find.text('Generate Local Preview'), findsOneWidget);
  });

  testWidgets('Generates an editable visual draft', (tester) async {
    await openStudio(tester);
    await generate(tester);

    expect(find.byKey(const ValueKey('select-component-c1')), findsOneWidget);

    expect(find.text('Save Visual Draft'), findsOneWidget);

    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);
  });

  testWidgets('Selects a component and edits its label', (tester) async {
    await openStudio(tester);
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    expect(find.text('Component Properties'), findsOneWidget);
    expect(find.text('Updated button'), findsWidgets);
  });

  testWidgets('Undo restores previous component label', (tester) async {
    await openStudio(tester);
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('step07-edit-label-c1')),
    );

    expect(field.initialValue, 'Continue');
  });

  testWidgets('Redo restores the edited label', (tester) async {
    await openStudio(tester);
    await generate(tester);
    await selectComponent(tester);
    await editLabel(tester);

    final undo = find.byKey(const ValueKey('step07-undo-button'));

    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pumpAndSettle();

    final redo = find.byKey(const ValueKey('step07-redo-button'));

    await tester.ensureVisible(redo);
    await tester.tap(redo);
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('step07-edit-label-c1')),
    );

    expect(field.initialValue, 'Updated button');
  });

  testWidgets('Blocks AI generation during unsaved editing', (tester) async {
    await openStudio(tester);
    await generate(tester);

    final generateButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Generate & Save Blueprint'),
    );

    final regenerateButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Safe AI Regeneration'),
    );

    expect(generateButton.onPressed, isNull);
    expect(regenerateButton.onPressed, isNull);
  });
}
