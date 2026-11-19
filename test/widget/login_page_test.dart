import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/authentication/presentation/pages/login_page.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_theme.dart';

void main() {
  Future<void> show(WidgetTester tester, LoginPage page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: ReqvioraTheme.light, home: page),
    );
  }

  testWidgets('Empty fields show validation errors', (tester) async {
    await show(tester, LoginPage(
      onSubmit: (email, password) async {},
    ));
    await tester.ensureVisible(
      find.byKey(const Key('login-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('Callback and loading state work', (tester) async {
    final pending = Completer<void>();
    String? received;
    await show(tester, LoginPage(
      onSubmit: (email, password) {
        received = email;
        return pending.future;
      },
    ));
    await tester.enterText(
      find.byType(TextFormField).at(0), 'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1), 'secret',
    );
    await tester.ensureVisible(
      find.byKey(const Key('login-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(received, 'user@example.com');
    expect(find.text('Signing in...'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Signing in...'), findsNothing);
  });

  testWidgets('Offline disables submit', (tester) async {
    await show(tester, LoginPage(
      isOffline: true,
      onSubmit: (email, password) async {},
    ));
    expect(find.byKey(const Key('login-offline')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('login-submit')),
      ).onPressed,
      isNull,
    );
  });
}
