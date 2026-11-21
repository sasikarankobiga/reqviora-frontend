
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reqviora_frontend/app/app.dart';

void main() {
  testWidgets(
    'REQVIORA application displays login page',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: ReqvioraApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('REQVIORA'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byKey(const Key('login_email')), findsOneWidget);
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      expect(find.byKey(const Key('login_button')), findsOneWidget);
    },
  );
}
