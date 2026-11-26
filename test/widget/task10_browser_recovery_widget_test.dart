import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/blueprint_recovery_store.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  const recovery = BlueprintRecoveryStore();

  Workspace makeWorkspace(String projectId, int version) {
    return Workspace(
      projectId: projectId,
      draftId: 'draft-$projectId',
      version: version,
      projectName: 'REQVIORA Recovery Test',
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
              'props': {'text': 'Saved original content'},
            },
          ],
        },
      },
    );
  }

  Future<void> openStudio(
    WidgetTester tester,
    String projectId,
    int version,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintStudio(
                workspace: makeWorkspace(projectId, version),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Unsaved edits survive reopening Step 07', (tester) async {
    const project = 'widget-recovery-reopen';
    recovery.clear(project);
    addTearDown(() => recovery.clear(project));

    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openStudio(tester, project, 1);

    final select = find.byKey(const ValueKey('select-component-title-1'));

    await tester.ensureVisible(select);
    await tester.tap(select);
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('step07-edit-text-title-1'));

    await tester.ensureVisible(input);
    await tester.enterText(input, 'Restored unsaved content');
    await tester.pumpAndSettle();

    expect(find.text('Restored unsaved content'), findsWidgets);
    expect(recovery.restore(project, 1), isNotNull);

    // Destroy the widget tree to simulate navigating away/reopening.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await openStudio(tester, project, 1);

    expect(find.text('Restored unsaved content'), findsWidgets);
    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New draft version rejects stale browser recovery', (
    tester,
  ) async {
    const project = 'widget-recovery-stale';
    recovery.clear(project);
    addTearDown(() => recovery.clear(project));

    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    recovery.save(project, 1, {
      'screens': [
        {'screenId': 'home', 'name': 'Home'},
      ],
      'componentInstances': [
        {
          'componentInstanceId': 'title-1',
          'screenId': 'home',
          'type': 'text',
          'props': {'text': 'Outdated unsaved content'},
        },
      ],
    });

    await openStudio(tester, project, 2);

    expect(find.text('Saved original content'), findsWidgets);
    expect(find.text('Outdated unsaved content'), findsNothing);
    expect(recovery.restore(project, 1), isNull);
    expect(tester.takeException(), isNull);
  });
}
