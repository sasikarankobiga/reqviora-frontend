import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

void main() {
  testWidgets('Saved font size and enabled flag affect preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafePreview(
              blueprint: {
                'screens': [
                  {'screenId': 'one', 'name': 'Home'},
                ],
                'componentInstances': [
                  {
                    'componentInstanceId': 't',
                    'screenId': 'one',
                    'type': 'text',
                    'props': {
                      'text': 'Saved title',
                      'fontSize': 32,
                      'alignment': 'center',
                    },
                  },
                  {
                    'componentInstanceId': 'b',
                    'screenId': 'one',
                    'type': 'button',
                    'props': {'label': 'Blocked', 'enabled': false},
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );
    final title = tester.widget<Text>(find.text('Saved title'));
    expect(title.style?.fontSize, 32);
    expect(title.textAlign, TextAlign.center);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Blocked'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tablet mode and disconnected screen selection work locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafePreview(
              blueprint: {
                'screens': [
                  {'screenId': 'one', 'name': 'Home'},
                  {'screenId': 'two', 'name': 'Details'},
                ],
                'componentInstances': [],
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('TABLET'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'TABLET'))
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('preview-screen-two')));
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
