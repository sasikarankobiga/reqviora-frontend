import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

Map<String, dynamic> makeBlueprint(Map<String, dynamic> tokens) => {
  'screens': [
    {'screenId': 'home', 'name': 'Home'},
  ],
  'componentInstances': [
    {
      'componentInstanceId': 'heading-1',
      'screenId': 'home',
      'type': 'header',
      'props': {'text': 'Welcome'},
    },
    {
      'componentInstanceId': 'box-1',
      'screenId': 'home',
      'type': 'container',
      'props': {'text': 'Details'},
    },
  ],
  'designTokens': tokens,
};

Future<void> openPreview(
  WidgetTester tester,
  Map<String, dynamic> tokens,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SafePreview(blueprint: makeBlueprint(tokens)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Preview applies saved font spacing and radius', (tester) async {
    await openPreview(tester, {
      'fontFamily': 'Arial',
      'baseSpacing': 12,
      'borderRadius': 24,
      'primaryColor': '#123456',
    });

    final heading = tester.widget<Text>(find.text('Welcome'));

    expect(heading.style?.fontFamily, 'Arial');

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('preview-parent-box-1')),
    );

    expect(container.padding, const EdgeInsets.all(24));

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(24));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid layout tokens use safe defaults', (tester) async {
    await openPreview(tester, {
      'fontFamily': '',
      'baseSpacing': -200,
      'borderRadius': 100,
    });

    final heading = tester.widget<Text>(find.text('Welcome'));

    expect(heading.style?.fontFamily, 'Roboto');

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('preview-parent-box-1')),
    );

    expect(container.padding, const EdgeInsets.all(16));

    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));

    expect(tester.takeException(), isNull);
  });
}
