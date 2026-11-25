import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/v4_blueprint_selection_panel.dart';

void main() {
  final blueprint = <String, dynamic>{
    'screens': [
      {'screenId': 'home', 'name': 'Home'},
      {'screenId': 'dashboard', 'name': 'Dashboard'},
    ],
    'componentInstances': [
      {
        'componentInstanceId': 'title-1',
        'screenId': 'home',
        'type': 'text',
        'props': {'text': 'Welcome'},
      },
      {
        'componentInstanceId': 'button-1',
        'screenId': 'dashboard',
        'type': 'button',
        'props': {'label': 'Continue'},
      },
    ],
  };

  testWidgets('lists components grouped under screens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V4BlueprintSelectionPanel(
            blueprint: blueprint,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('selection returns component instance ID', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V4BlueprintSelectionPanel(
            blueprint: blueprint,
            onSelected: (id) => selected = id,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('select-component-title-1')));
    await tester.pump();

    expect(selected, 'title-1');
  });

  testWidgets('empty blueprint shows safe placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V4BlueprintSelectionPanel(
            blueprint: const {},
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Compile a Blueprint to select components'),
      findsOneWidget,
    );
  });
}
