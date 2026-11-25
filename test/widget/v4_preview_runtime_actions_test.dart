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
            'componentInstanceId': 'submit',
            'screenId': 'home',
            'type': 'button',
            'props': {'label': 'Submit'},
          },
          {
            'componentInstanceId': 'input-1',
            'screenId': 'home',
            'type': 'input',
            'props': {'label': 'Email'},
          },
          {
            'componentInstanceId': 'state-message',
            'screenId': 'home',
            'type': 'text',
            'props': {
              'text': 'Success visible',
              'visibility': {
                'mode': 'state',
                'state': 'success',
              },
            },
          },
          {
            'componentInstanceId': 'dashboard-title',
            'screenId': 'dashboard',
            'type': 'text',
            'props': {'text': 'Dashboard content'},
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
            child: SafePreview(
              blueprint: blueprint(),
              interactionRules: rules,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('button navigates to configured screen', (tester) async {
    await openPreview(tester, [
      {
        'componentId': 'submit',
        'trigger': 'onClick',
        'action': 'navigate',
        'targetScreenId': 'dashboard',
      }
    ]);

    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard content'), findsOneWidget);
  });

  testWidgets('button shows configured message', (tester) async {
    await openPreview(tester, [
      {
        'componentId': 'submit',
        'trigger': 'onClick',
        'action': 'show-message',
        'message': 'Saved successfully',
      }
    ]);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Saved successfully'), findsOneWidget);
  });

  testWidgets('input change updates preview state', (tester) async {
    await openPreview(tester, [
      {
        'componentId': 'input-1',
        'trigger': 'onChange',
        'action': 'set-state',
        'targetState': 'success',
      }
    ]);

    expect(find.text('Success visible'), findsNothing);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pumpAndSettle();

    expect(find.text('Success visible'), findsOneWidget);
  });

  testWidgets('button without rule keeps safe mock action', (tester) async {
    await openPreview(tester, []);

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(

testWidgets('button without rule keeps safe mock action', (tester) async {
  await openPreview(tester, []);

  await tester.tap(find.text('Submit'));
  await tester.pump();

  expect(
    find.text('Preview-only action - No backend request was made'),
    findsOneWidget,
  );
});

}


