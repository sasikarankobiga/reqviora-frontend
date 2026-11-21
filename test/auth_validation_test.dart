
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reqviora_frontend/app/app.dart';

void main() {
  testWidgets(
    'Login and Register forms validate user input',
    (WidgetTester tester) async {
      // Start the application.
      await tester.pumpWidget(
        const ProviderScope(
          child: ReqvioraApp(),
        ),
      );

      await tester.pumpAndSettle();

      // TEST 1: Login page renders.
      expect(find.text('Welcome Back'), findsOneWidget);

      // TEST 2: Empty login form shows errors.
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // TEST 3: Invalid email is rejected.
      await tester.enterText(
        find.byKey(const Key('login_email')),
        'invalid-email',
      );

      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);

      // TEST 4: Navigate from Login to Register.
      // Scroll until the Register link is visible.
      await tester.ensureVisible(find.text('Register'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsWidgets);

      // TEST 5: Empty registration form shows errors.
      await tester.ensureVisible(
        find.byKey(const Key('register_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('register_button')),
      );
      await tester.pump();

      expect(
        find.text('Full name is required'),
        findsOneWidget,
      );
      expect(
        find.text('Email is required'),
        findsOneWidget,
      );
      expect(
        find.text('Password is required'),
        findsOneWidget,
      );
      expect(
        find.text('Confirm your password'),
        findsOneWidget,
      );

      // TEST 6: Password mismatch is rejected.
      await tester.enterText(
        find.byKey(const Key('register_password')),
        'Password123',
      );

      await tester.enterText(
        find.byKey(const Key('register_confirm_password')),
        'Different123',
      );

      // Ensure the button is visible before clicking.
      await tester.ensureVisible(
        find.byKey(const Key('register_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('register_button')),
      );
      await tester.pump();

      expect(
        find.text('Passwords do not match'),
        findsOneWidget,
      );
    },
  );
}
