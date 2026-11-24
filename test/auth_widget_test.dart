import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reqviora_frontend/features/auth/presentation/auth_page.dart';

void main() {
  Future<void> openAuthPage(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthPage())),
    );
  }

  testWidgets('Login form displays email and password', (tester) async {
    await openAuthPage(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password')), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Registration form displays confirm password', (tester) async {
    await openAuthPage(tester);

    await tester.tap(find.byKey(const ValueKey('auth-switch-mode')));

    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);

    expect(find.byKey(const ValueKey('auth-confirm-password')), findsOneWidget);
  });

  testWidgets('Invalid email displays validation error', (tester) async {
    await openAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'invalid-email',
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPassword123',
    );

    await tester.tap(find.byKey(const ValueKey('auth-submit')));

    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('Password visibility toggles', (tester) async {
    await openAuthPage(tester);

    final passwordField = find.byKey(const ValueKey('auth-password'));

    final editableText = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );

    // Initially password must be hidden.
    expect(tester.widget<EditableText>(editableText).obscureText, isTrue);

    // Show password.
    await tester.tap(find.byTooltip('Show password'));

    await tester.pump();

    expect(tester.widget<EditableText>(editableText).obscureText, isFalse);

    // Hide password again.
    await tester.tap(find.byTooltip('Hide password'));

    await tester.pump();

    expect(tester.widget<EditableText>(editableText).obscureText, isTrue);
  });
}
