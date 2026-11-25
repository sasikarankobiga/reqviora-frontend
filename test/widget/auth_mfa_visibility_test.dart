import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/auth/presentation/auth_page.dart';

void main() {
  Future<void> openPage(
    WidgetTester tester, {
    bool register = false,
    Size size = const Size(900, 1000),
  }) async {
    await tester.binding.setSurfaceSize(size);

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: AuthPage(register: register))),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Normal login hides the authenticator field', (tester) async {
    await openPage(tester);

    expect(find.byKey(const ValueKey('auth-email')), findsOneWidget);

    expect(find.byKey(const ValueKey('auth-password')), findsOneWidget);

    expect(find.byKey(const ValueKey('auth-otp')), findsNothing);

    expect(find.byKey(const ValueKey('auth-toggle-mfa')), findsOneWidget);
  });

  testWidgets('Authenticator field can be enabled and hidden', (tester) async {
    await openPage(tester);

    final toggle = find.byKey(const ValueKey('auth-toggle-mfa'));

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final otp = find.byKey(const ValueKey('auth-otp'));

    expect(otp, findsOneWidget);

    await tester.ensureVisible(otp);
    await tester.enterText(otp, '123456');

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(otp, findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(otp);

    expect(field.controller!.text, isEmpty);
  });

  testWidgets('Registration does not show MFA controls', (tester) async {
    await openPage(tester, register: true);

    expect(find.byKey(const ValueKey('auth-otp')), findsNothing);

    expect(find.byKey(const ValueKey('auth-toggle-mfa')), findsNothing);

    expect(find.byKey(const ValueKey('auth-confirm-password')), findsOneWidget);
  });

  testWidgets('Login renders at narrow mobile width', (tester) async {
    await openPage(tester, size: const Size(360, 800));

    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('auth-submit')), findsOneWidget);
  });

  testWidgets('Registration renders at narrow mobile width', (tester) async {
    await openPage(tester, register: true, size: const Size(360, 800));

    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('auth-submit')), findsOneWidget);
  });
}
