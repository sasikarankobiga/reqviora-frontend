import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

void main() {
  testWidgets('Local Blueprint renders screens and mock navigation', (
    tester,
  ) async {
    final blueprint = <String, dynamic>{
      'previewOnly': true,
      'screens': [
        {'screenId': 'home', 'name': 'Home'},
        {'screenId': 'details', 'name': 'Details'},
      ],
      'componentInstances': [
        {
          'componentInstanceId': 'welcome',
          'screenId': 'home',
          'type': 'text',
          'order': 0,
          'props': {'text': 'Welcome to REQVIORA'},
        },
      ],
      'routes': [
        {
          'sourceScreenId': 'home',
          'targetScreenId': 'details',
          'enabled': true,
        },
      ],
      'designTokens': {'primaryColor': '#6654E8'},
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SafePreview(blueprint: blueprint)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome to REQVIORA'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    final navigation = find.widgetWithText(OutlinedButton, 'Details');

    expect(navigation, findsOneWidget);

    await tester.ensureVisible(navigation);
    await tester.tap(navigation);
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Welcome to REQVIORA'), findsNothing);
  });
}
