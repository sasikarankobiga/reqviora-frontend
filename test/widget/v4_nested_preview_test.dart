import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

void main() {
  Future<void> openPreview(
    WidgetTester tester,
    List<Map<String, dynamic>> components,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafePreview(
              blueprint: {
                'screens': [
                  {'screenId': 'screen-1', 'name': 'Dashboard'},
                ],
                'componentInstances': components,
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('renders nested Card Container Text and Button', (tester) async {
    await openPreview(tester, [
      {
        'componentInstanceId': 'card-1',
        'screenId': 'screen-1',
        'type': 'card',
        'props': {'text': 'Profile Card'},
      },
      {
        'componentInstanceId': 'container-1',
        'parentComponentId': 'card-1',
        'screenId': 'screen-1',
        'type': 'container',
        'props': {'text': 'Details Container'},
      },
      {
        'componentInstanceId': 'text-1',
        'parentComponentId': 'container-1',
        'screenId': 'screen-1',
        'type': 'text',
        'props': {'text': 'Nested Profile Text'},
      },
      {
        'componentInstanceId': 'button-1',
        'parentComponentId': 'card-1',
        'screenId': 'screen-1',
        'type': 'button',
        'props': {'label': 'Edit Profile'},
      },
    ]);

    expect(find.text('Profile Card'), findsOneWidget);
    expect(find.text('Details Container'), findsOneWidget);
    expect(find.text('Nested Profile Text'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);

    final parent = find.byKey(
      const ValueKey('preview-parent-card-1'),
    );

    final childContainer = find.byKey(
      const ValueKey('preview-parent-container-1'),
    );

    expect(parent, findsOneWidget);
    expect(childContainer, findsOneWidget);

    expect(
      find.ancestor(
        of: childContainer,
        matching: parent,
      ),
      findsOneWidget,
    );

    expect(
      find.ancestor(
        of: find.text('Nested Profile Text'),
        matching: childContainer,
      ),
      findsOneWidget,
    );

    expect(
      find.ancestor(
        of: find.text('Edit Profile'),
        matching: parent,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders an orphan component as a root', (tester) async {
    await openPreview(tester, [
      {
        'componentInstanceId': 'orphan-text',
        'parentComponentId': 'missing-parent',
        'screenId': 'screen-1',
        'type': 'text',
        'props': {'text': 'Visible Orphan Text'},
      },
    ]);

    expect(find.text('Visible Orphan Text'), findsOneWidget);
  });

  testWidgets('prevents infinite recursion in circular hierarchy',
      (tester) async {
    await openPreview(tester, [
      {
        'componentInstanceId': 'card-a',
        'parentComponentId': 'card-b',
        'screenId': 'screen-1',
        'type': 'card',
        'props': {'text': 'Card A'},
      },
      {
        'componentInstanceId': 'card-b',
        'parentComponentId': 'card-a',
        'screenId': 'screen-1',
        'type': 'card',
        'props': {'text': 'Card B'},
      },
    ]);

    expect(
      find.text('Invalid nested component reference'),
      findsWidgets,
    );

    expect(tester.takeException(), isNull);
  });
}
