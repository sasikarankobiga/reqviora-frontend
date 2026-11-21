import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/app/app.dart';

void main() {
  testWidgets(
    'Dashboard to Input Studio navigation works',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ReqvioraApp(),
      );

      // Dashboard loaded
      expect(
        find.text('YOUR IDEAS, IN MOTION'),
        findsOneWidget,
      );

      // Dashboard -> Create Project
      await tester.tap(
        find.text('Create Project'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Create a New Project'),
        findsOneWidget,
      );

      // Create Project -> Overview
      await tester.tap(
        find.text('Continue (Navigation Demo)'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Open Input Studio'),
        findsOneWidget,
      );

      // Overview -> Input Studio
      await tester.tap(
        find.text('Open Input Studio'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Input Studio'),
        findsWidgets,
      );
    },
  );
}
