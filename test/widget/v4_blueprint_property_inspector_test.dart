import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/v4_blueprint_property_inspector.dart';

void main() {
  Future<void> openInspector(
    WidgetTester tester, {
    required Map<String, dynamic>? component,
    required ValueChanged<Map<String, dynamic>> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V4BlueprintPropertyInspector(
            component: component,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('no selection shows placeholder', (tester) async {
    await openInspector(
      tester,
      component: null,
      onChanged: (_) {},
    );

    expect(
      find.text('Select a component to edit its properties'),
      findsOneWidget,
    );
  });

  testWidgets('text editing preserves component ID', (tester) async {
    Map<String, dynamic>? updated;

    await openInspector(
      tester,
      component: {
        'componentInstanceId': 'title-1',
        'type': 'text',
        'screenId': 'home',
        'props': {
          'text': 'Welcome',
          'alignment': 'center',
        },
      },
      onChanged: (value) => updated = value,
    );

    await tester.enterText(
      find.byKey(const ValueKey('step07-edit-text-title-1')),
      'Hello REQVIORA',
    );

    expect(updated?['componentInstanceId'], 'title-1');
    expect(updated?['screenId'], 'home');

    final props = updated?['props'] as Map<String, dynamic>;

    expect(props['text'], 'Hello REQVIORA');
    expect(props['alignment'], 'center');
  });

  testWidgets('button label editing preserves custom props', (tester) async {
    Map<String, dynamic>? updated;

    await openInspector(
      tester,
      component: {
        'componentInstanceId': 'button-1',
        'type': 'button',
        'props': {
          'label': 'Continue',
          'variant': 'primary',
        },
      },
      onChanged: (value) => updated = value,
    );

    await tester.enterText(
      find.byKey(const ValueKey('step07-edit-label-button-1')),
      'Submit',
    );

    final props = updated?['props'] as Map<String, dynamic>;

    expect(props['label'], 'Submit');
    expect(props['variant'], 'primary');
  });

  testWidgets('legacy properties field remains supported', (tester) async {
    Map<String, dynamic>? updated;

    await openInspector(
      tester,
      component: {
        'componentInstanceId': 'button-2',
        'type': 'button',
        'properties': {'label': 'Save'},
      },
      onChanged: (value) => updated = value,
    );

    await tester.enterText(
      find.byKey(const ValueKey('step07-edit-label-button-2')),
      'Save Draft',
    );

    expect(
      (updated?['properties'] as Map<String, dynamic>)['label'],
      'Save Draft',
    );
    expect(updated!.containsKey('props'), false);
  });
}
