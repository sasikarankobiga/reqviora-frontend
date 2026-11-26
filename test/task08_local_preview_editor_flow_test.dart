import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets(
    'Local preview becomes an editable, unsaved Blueprint draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final workspace = Workspace(
        projectId: 'project-local',
        draftId: 'draft-local',
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
              'text': 'Hello',
              'label': 'Welcome',
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

      expect(
        find.byKey(const ValueKey('step07-save-draft-button')),
        findsNothing,
      );

      final generate = find.text('Generate Local Preview');

      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('step07-save-draft-button')),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey('select-component-welcome')),
        findsOneWidget,
      );

      expect(
        find.byKey(const ValueKey('step07-unsaved-notice')),
        findsOneWidget,
      );

      expect(find.text('Hello'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Regeneration requires confirmation before replacing manual edits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final workspace = Workspace(
        projectId: 'project-manual',
        draftId: 'draft-manual',
        version: 3,
        projectName: 'REQVIORA',
        designTargets: const ['web'],
        sections: {
          'screens': [
            {'id': 'home', 'name': 'Home'},
          ],
          'components': [
            {
              'id': 'generated',
              'screenId': 'home',
              'type': 'text',
              'text': 'Generated replacement',
            },
          ],
          'routes': <Map<String, dynamic>>[],
          'blueprint': {
            'previewOnly': true,
            'screens': [
              {'screenId': 'home', 'name': 'Home'},
            ],
            'componentInstances': [
              {
                'componentInstanceId': 'manual',
                'screenId': 'home',
                'type': 'text',
                'order': 0,
                'props': {'text': 'Manual design'},
              },
            ],
            'routes': <Map<String, dynamic>>[],
            'designTokens': {'primaryColor': '#6654E8'},
          },
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

      expect(find.text('Manual design'), findsWidgets);

      final generate = find.text('Generate Local Preview');

      await tester.ensureVisible(generate);
      await tester.tap(generate);
      await tester.pumpAndSettle();

      expect(
        find.text('Replace the current Blueprint draft?'),
        findsOneWidget,
      );

      final keepCurrent = find.text('Keep Current');

      await tester.ensureVisible(keepCurrent);
      await tester.tap(keepCurrent);
      await tester.pumpAndSettle();

      expect(find.text('Manual design'), findsWidgets);
      expect(find.text('Generated replacement'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}