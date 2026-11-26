import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/v4_blueprint_selection_panel.dart';

void main() {
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

  Future<void> checkAccessibility(
    WidgetTester tester,
    Size size,
    double scale,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final semantics = tester.ensureSemantics();
    addTearDown(() {});

    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: V4BlueprintSelectionPanel(
                      blueprint: blueprint,
                      onSelected: (id) => selected = id,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(androidTapTargetGuideline));

    final target = find.byKey(const ValueKey('select-component-title-1'));

    expect(target, findsOneWidget);

    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();

    expect(selected, 'title-1');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }

  testWidgets('Tablet accessibility at 160 percent text size', (tester) async {
    await checkAccessibility(tester, const Size(768, 1024), 1.6);
  });

  testWidgets('Desktop accessibility at 200 percent text size', (tester) async {
    await checkAccessibility(tester, const Size(1280, 900), 2.0);
  });
}
