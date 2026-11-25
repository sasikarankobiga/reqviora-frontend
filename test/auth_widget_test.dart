import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reqviora_frontend/features/auth/presentation/auth_page.dart';

void main() {
  Future<GoRouter> openAuthPage(
    WidgetTester tester, {
    String initialLocation = '/login',
  }) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const AuthPage()),
        GoRoute(
          path: '/register',
          builder: (_, _) => const AuthPage(register: true),
        ),
      ],
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Login form displays email and password', (tester) async {
    await openAuthPage(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password')), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Register link updates URL', (tester) async {
    final router = await openAuthPage(tester);

    final switchButton = find.byKey(const ValueKey('auth-switch-mode'));

    await tester.ensureVisible(switchButton);
    await tester.pumpAndSettle();

    await tester.tap(switchButton);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/register');
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-confirm-password')), findsOneWidget);
  });

  testWidgets('Register page supports direct navigation', (tester) async {
    final router = await openAuthPage(tester, initialLocation: '/register');

    expect(router.routeInformationProvider.value.uri.path, '/register');
    expect(find.text('Create your account'), findsOneWidget);

    final switchButton = find.byKey(const ValueKey('auth-switch-mode'));

    await tester.ensureVisible(switchButton);
    await tester.pumpAndSettle();

    await tester.tap(switchButton);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(find.text('Welcome back'), findsOneWidget);
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

    expect(tester.widget<EditableText>(editableText).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(tester.widget<EditableText>(editableText).obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();

    expect(tester.widget<EditableText>(editableText).obscureText, isTrue);
  });
  testWidgets('Login keyboard Done validates the form', (tester) async {
    await openAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'invalid-email',
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPassword123',
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('Register keyboard Done validates confirmation', (tester) async {
    await openAuthPage(tester, initialLocation: '/register');

    await tester.enterText(
      find.byKey(const ValueKey('auth-display-name')),
      'Test User',
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'test@example.com',
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'StrongPassword123',
    );

    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password')),
      'DifferentPassword123',
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
  testWidgets('Login email Next focuses password', (tester) async {
    await openAuthPage(tester);

    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'test@example.com',
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final password = find.descendant(
      of: find.byKey(const ValueKey('auth-password')),
      matching: find.byType(EditableText),
    );

    expect(tester.widget<EditableText>(password).focusNode.hasFocus, isTrue);
  });

  testWidgets('Register name Next focuses email', (tester) async {
    await openAuthPage(tester, initialLocation: '/register');

    await tester.enterText(
      find.byKey(const ValueKey('auth-display-name')),
      'Test User',
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final email = find.descendant(
      of: find.byKey(const ValueKey('auth-email')),
      matching: find.byType(EditableText),
    );

    expect(tester.widget<EditableText>(email).focusNode.hasFocus, isTrue);
  });
}
