import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

void main() {
  Map<String, dynamic> blueprint() => {
    'screens': [
      {'screenId': 'home', 'name': 'Home'},
      {'screenId': 'dashboard', 'name': 'Dashboard'},
    ],
    'componentInstances': [
      {
        'componentInstanceId': 'button-instance-1',
        'templateSourceId': 'original-button',
        'screenId': 'home',
        'type': 'button',
        'props': {'label': 'Open Dashboard'},
      },
      {
        'componentInstanceId': 'email-instance',
        'screenId': 'home',
        'type': 'input',
        'props': {'label': 'Email'},
      },
      {
        'componentInstanceId': 'result-text',
        'screenId': 'home',
        'type': 'text',
        'props': {
          'text': 'Form submitted',
          'visibility': {'mode': 'state', 'state': 'success'},
        },
      },
      {
        'componentInstanceId': 'dashboard-title',
        'screenId': 'dashboard',
        'type': 'text',
        'props': {'text': 'Dashboard opened'},
      },
    ],
  };

  Future<void> openPreview(
    WidgetTester tester,
    List<Map<String, dynamic>> rules,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafePreview(blueprint: blueprint(), interactionRules: rules),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('reused component resolves original source ID', (tester) async {
    await openPreview(tester, [
      {
        'componentId': 'original-button',
        'trigger': 'onClick',
        'action': 'navigate',
        'targetScreenId': 'dashboard',
      },
    ]);

    await tester.tap(find.widgetWithText(FilledButton, 'Open Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard opened'), findsOneWidget);
  });

  testWidgets('invalid navigation destination is not opened', (tester) async {
    await openPreview(tester, [
      {
        'componentId': 'original-button',
        'trigger': 'onClick',
        'action': 'navigate',
        'targetScreenId': 'missing-screen',
      },
    ]);

    await tester.tap(find.widgetWithText(FilledButton, 'Open Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard opened'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('input onSubmit executes configured state action', (
    tester,
  ) async {
    await openPreview(tester, [
      {
        'componentId': 'email-instance',
        'trigger': 'onSubmit',
        'action': 'set-state',
        'targetState': 'success',
      },
    ]);

    expect(find.text('Form submitted'), findsNothing);

    await tester.enterText(find.byType(TextField), 'hello@example.com');

    // Entering text must not execute an onSubmit-only rule.
    await tester.pumpAndSettle();
    expect(find.text('Form submitted'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Form submitted'), findsOneWidget);
  });
}
