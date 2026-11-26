import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

Future<void> openPreview(
  WidgetTester tester,
  Map<String, dynamic> blueprint, {
  String simulationState = 'default',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SafePreview(
            blueprint: blueprint,
            simulationState: simulationState,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Map<String, dynamic> blueprint({
  List<Map<String, dynamic>> components = const [],
  List<Map<String, dynamic>> routes = const [],
}) => {
  'screens': [
    {'screenId': 'screen-1', 'name': 'Home'},
  ],
  'componentInstances': components,
  'routes': routes,
};

void main() {
  testWidgets('External images remain offline placeholders', (tester) async {
    await openPreview(
      tester,
      blueprint(
        components: [
          {
            'componentInstanceId': 'image-1',
            'screenId': 'screen-1',
            'type': 'image',
            'props': {
              'src': 'https://example.invalid/image.png',
              'alt': 'Project image',
            },
          },
        ],
      ),
    );

    expect(
      find.byKey(const ValueKey('safe-preview-image-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Malformed screen collection is handled safely', (tester) async {
    await openPreview(tester, {'screens': 'invalid'});

    expect(find.text('No screens in blueprint'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid route targets are not rendered', (tester) async {
    await openPreview(
      tester,
      blueprint(
        routes: [
          {
            'sourceScreenId': 'screen-1',
            'targetScreenId': 'missing-screen',
            'enabled': true,
          },
        ],
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Next screen'), findsNothing);
    expect(find.text('Preview navigation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disabled buttons cannot execute interactions', (tester) async {
    await openPreview(
      tester,
      blueprint(
        components: [
          {
            'componentInstanceId': 'button-1',
            'screenId': 'screen-1',
            'type': 'button',
            'props': {'label': 'Submit', 'disabled': true},
          },
        ],
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Submit'),
    );

    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disabled simulation state locks input fields', (tester) async {
    await openPreview(
      tester,
      blueprint(
        components: [
          {
            'componentInstanceId': 'input-1',
            'screenId': 'screen-1',
            'type': 'input',
            'props': {'label': 'Name'},
          },
        ],
      ),
      simulationState: 'disabled',
    );

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Invalid component order does not crash preview', (tester) async {
    await openPreview(
      tester,
      blueprint(
        components: [
          {
            'componentInstanceId': 'text-1',
            'screenId': 'screen-1',
            'type': 'text',
            'order': 'invalid',
            'props': {'text': 'Welcome'},
          },
          {
            'componentInstanceId': 'text-2',
            'screenId': 'screen-1',
            'type': 'text',
            'order': 2,
            'props': {'text': 'Second item'},
          },
        ],
      ),
    );

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Second item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Twelve chart bars fit in mobile preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await openPreview(
      tester,
      blueprint(
        components: [
          {
            'componentInstanceId': 'chart-1',
            'screenId': 'screen-1',
            'type': 'chart',
            'props': {'values': List.generate(12, (index) => index + 1)},
          },
        ],
      ),
    );

    expect(find.byKey(const ValueKey('preview-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
