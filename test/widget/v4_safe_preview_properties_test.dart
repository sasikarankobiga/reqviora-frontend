import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

void main() {
  Future<void> openPreview(
    WidgetTester tester, {
    required String type,
    required Map<String, dynamic> properties,
    bool usePropertiesKey = false,
  }) async {
    final blueprint = <String, dynamic>{
      'screens': [
        {'screenId': 'screen-1', 'name': 'Dashboard'},
      ],
      'componentInstances': [
        {
          'componentInstanceId': 'component-1',
          'screenId': 'screen-1',
          'order': 0,
          'type': type,
          usePropertiesKey ? 'properties' : 'props': properties,
        },
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafePreview(blueprint: blueprint),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders header right alignment', (tester) async {
    await openPreview(
      tester,
      type: 'header',
      properties: {
        'text': 'Preview Heading',
        'alignment': 'right',
      },
    );

    final heading = tester.widget<Text>(find.text('Preview Heading'));
    expect(heading.textAlign, TextAlign.right);
  });

  testWidgets('renders dense list chips', (tester) async {
    await openPreview(
      tester,
      type: 'list',
      properties: {
        'dense': true,
        'items': ['Alpha', 'Beta'],
      },
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    final chips = tester.widgetList<Chip>(find.byType(Chip)).toList();
    expect(chips, hasLength(2));

    for (final chip in chips) {
      expect(chip.visualDensity, VisualDensity.compact);
    }
  });

  testWidgets('renders striped table rows', (tester) async {
    await openPreview(
      tester,
      type: 'table',
      properties: {
        'stripedRows': true,
        'items': ['Row A', 'Row B', 'Row C'],
      },
    );

    expect(find.text('Row A'), findsOneWidget);
    expect(find.text('Row B'), findsOneWidget);
    expect(find.text('Row C'), findsOneWidget);

    final rowBContainers = tester.widgetList<Container>(
      find.ancestor(
        of: find.text('Row B'),
        matching: find.byType(Container),
      ),
    );

    expect(
      rowBContainers.any(
        (container) => container.color == const Color(0xFFF1EFFB),
      ),
      isTrue,
    );
  });

  testWidgets('uses image placeholder for invalid source', (tester) async {
    await openPreview(
      tester,
      type: 'image',
      properties: {
        'src': 'not-a-valid-url',
        'alt': 'Profile image',
      },
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('supports properties fallback for compiled components',
      (tester) async {
    await openPreview(
      tester,
      type: 'header',
      usePropertiesKey: true,
      properties: {
        'text': 'Fallback Heading',
        'alignment': 'center',
      },
    );

    final heading = tester.widget<Text>(find.text('Fallback Heading'));
    expect(heading.textAlign, TextAlign.center);
  });
}
