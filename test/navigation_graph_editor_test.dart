import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/navigation_graph_editor.dart';

void main() {
  Workspace workspace({
    bool empty = false,
    Map<String, dynamic> layout = const {},
  }) => Workspace(
    projectId: 'project-1',
    draftId: 'draft-1',
    version: 1,
    projectName: 'Navigation Test',
    designTargets: ['web'],
    sections: {
      'screens':
          empty
              ? []
              : [
                {'id': 's1', 'name': 'Home'},
                {'id': 's2', 'name': 'Dashboard'},
              ],
      'routes':
          empty
              ? []
              : [
                {'id': 'r1', 'fromScreenId': 's1', 'toScreenId': 's2'},
              ],
      'navigationLayout': layout,
    },
  );

  Future<void> openGraph(WidgetTester tester, Workspace value) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NavigationGraphEditor(workspace: value),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Shows empty screen guidance', (tester) async {
    await openGraph(tester, workspace(empty: true));

    expect(
      find.text('Add screens in Step 02 to build your navigation graph.'),
      findsOneWidget,
    );
  });

  testWidgets('Displays screens and route count', (tester) async {
    await openGraph(tester, workspace());

    expect(find.text('Visual Navigation Map'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('2 screens'), findsOneWidget);
    expect(find.text('1 routes'), findsOneWidget);
  });

  testWidgets('Disables saving unchanged layout', (tester) async {
    await openGraph(tester, workspace());

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Layout'),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('Auto layout marks changes as unsaved', (tester) async {
    await openGraph(tester, workspace());

    await tester.tap(find.text('Auto Layout'));
    await tester.pumpAndSettle();

    expect(find.text('You have unsaved layout changes.'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Layout'),
    );

    expect(button.onPressed, isNotNull);
  });

  testWidgets('Restores saved node coordinates', (tester) async {
    await openGraph(
      tester,
      workspace(
        layout: {
          's1': {'x': 150, 'y': 120},
        },
      ),
    );

    final nodes = tester.widgetList<Positioned>(
      find.descendant(
        of: find.byType(NavigationGraphEditor),
        matching: find.byType(Positioned),
      ),
    );

    expect(nodes.any((node) => node.left == 150 && node.top == 120), isTrue);
  });
}
