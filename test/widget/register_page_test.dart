import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/authentication/presentation/pages/register_page.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_theme.dart';

void main() {
  Future<void> show(WidgetTester tester, RegisterPage page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: ReqvioraTheme.light, home: page),
    );
  }

  testWidgets('Mismatch blocks registration', (tester) async {
    var called = false;
    await show(tester, RegisterPage(
      onSubmit: (email, password) async { called = true; },
    ));
    await tester.enterText(
      find.byType(TextFormField).at(0), 'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1), 'one',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2), 'two',
    );
    await tester.ensureVisible(
      find.byKey(const Key('register-submit')),
    );
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('Submitting shows loading state', (tester) async {
    final pending = Completer<void>();
    await show(tester, RegisterPage(
      onSubmit: (email, password) => pending.future,
    ));
    await tester.enterText(
      find.byType(TextFormField).at(0), 'user@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1), 'same',
    );
    await tester.enterText(
      find.byType(TextFormField).at(2), 'same',
    );
    await tester.ensureVisible(
      find.byKey(const Key('register-submit')),
    );
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    expect(find.text('Creating account...'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Offline disables registration', (tester) async {
    await show(tester, const RegisterPage(isOffline: true));
    expect(find.byKey(const Key('register-offline')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.byKey(const Key('register-submit')),
      ).onPressed,
      isNull,
    );
  });
}
