import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets('Unsaved Blueprint draft cannot be regenerated over edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = Workspace(
      projectId: 'project-recovery',
      draftId: 'draft-recovery',
      version: 1,
      projectName: 'REQVIORA',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 'home', 'name': 'Home'},
        ],
        'components': [
          {
            'id': 'welcome',
            'screenId': 'home',
            'type': 'text',
            'text': 'Original',
          },
        ],
        'routes': <Map<String, dynamic>>[],
        'blueprint': <String, dynamic>{},
        'interactions': <Map<String, dynamic>>[],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintStudio(workspace: workspace),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final generate = find.widgetWithText(
      OutlinedButton,
      'Generate Local Preview',
    );

    expect(tester.widget<OutlinedButton>(generate).onPressed, isNotNull);

    await tester.ensureVisible(generate);
    await tester.tap(generate);
    await tester.pumpAndSettle();

    expect(tester.widget<OutlinedButton>(generate).onPressed, isNull);

    final component = find.byKey(const ValueKey('select-component-welcome'));

    await tester.ensureVisible(component);
    await tester.tap(component);
    await tester.pumpAndSettle();

    final input = find.byKey(const ValueKey('step07-edit-text-welcome'));

    await tester.enterText(input, 'Unsaved updated text');
    await tester.pumpAndSettle();

    expect(find.text('Unsaved updated text'), findsWidgets);
    expect(find.byKey(const ValueKey('step07-unsaved-notice')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(generate).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
