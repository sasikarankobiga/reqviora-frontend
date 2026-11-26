import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

Map<String, dynamic> blueprint(Map<String, dynamic> tokens) => {
  'screens': [
    {'screenId': 'home', 'name': 'Home'},
    {'screenId': 'details', 'name': 'Details'},
  ],
  'componentInstances': [
    {
      'componentInstanceId': 'heading',
      'screenId': 'home',
      'type': 'header',
      'props': {'text': 'Welcome'},
    },
    {
      'componentInstanceId': 'card',
      'screenId': 'home',
      'type': 'container',
      'props': {'text': 'Card content'},
    },
  ],
  'routes': [
    {'sourceScreenId': 'home', 'targetScreenId': 'details', 'enabled': true},
  ],
  'designTokens': tokens,
};

Future<void> mountPreview(
  WidgetTester tester,
  Map<String, dynamic> tokens, {
  Brightness platformBrightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MediaQuery(
            data: MediaQueryData(platformBrightness: platformBrightness),
            child: SafePreview(blueprint: blueprint(tokens)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color canvasColor(WidgetTester tester) {
  final canvas = tester.widget<Container>(
    find.byKey(const ValueKey('preview-canvas')),
  );
  return (canvas.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('Dark theme uses a dark preview canvas', (tester) async {
    await mountPreview(tester, {'mode': 'dark'});

    expect(canvasColor(tester), const Color(0xFF1B2130));

    final heading = tester.widget<Text>(find.text('Welcome'));
    expect(heading.style?.color, Colors.white);

    final card = tester.widget<Container>(
      find.byKey(const ValueKey('preview-parent-card')),
    );
    expect((card.decoration as BoxDecoration).color, const Color(0xFF2B3345));

    expect(tester.takeException(), isNull);
  });

  testWidgets('System mode follows the platform brightness', (tester) async {
    await mountPreview(tester, {
      'mode': 'system',
    }, platformBrightness: Brightness.dark);

    expect(canvasColor(tester), const Color(0xFF1B2130));

    await mountPreview(tester, {
      'mode': 'system',
    }, platformBrightness: Brightness.light);

    expect(canvasColor(tester), Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Secondary color styles preview navigation', (tester) async {
    await mountPreview(tester, {'mode': 'light', 'secondaryColor': '#126A8A'});

    final navigation = find.widgetWithText(OutlinedButton, 'Details');
    expect(navigation, findsOneWidget);

    final button = tester.widget<OutlinedButton>(navigation);
    final color = button.style?.foregroundColor?.resolve(<WidgetState>{});

    expect(color, const Color(0xFF126A8A));
    expect(tester.takeException(), isNull);
  });
}
