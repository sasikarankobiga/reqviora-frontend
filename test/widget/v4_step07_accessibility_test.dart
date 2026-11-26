import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/v4_blueprint_selection_panel.dart';

void main() {
  testWidgets('Step 07 component selection meets accessibility guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final blueprint = <String, dynamic>{
        'screens': [
          {'screenId': 'home', 'name': 'Home'},
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
            'screenId': 'home',
            'type': 'button',
            'props': {'label': 'Continue'},
          },
        ],
      };

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4BlueprintSelectionPanel(
                blueprint: blueprint,
                onSelected: (id) => selected = id,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester, meetsGuideline(labeledTapTargetGuideline));

      expect(tester, meetsGuideline(androidTapTargetGuideline));

      final component = find.byKey(const ValueKey('select-component-title-1'));

      await tester.tap(component);
      await tester.pump();

      expect(selected, 'title-1');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
