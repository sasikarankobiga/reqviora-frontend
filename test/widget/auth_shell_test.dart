import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_theme.dart';

void main() {
  Future<void> showAt(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ReqvioraTheme.light,
        home: const AuthShell(
          title: 'Welcome back',
          subtitle: 'Sign in',
          form: Text('Test form'),
        ),
      ),
    );
  }

  testWidgets('Desktop shows split layout', (tester) async {
    await showAt(tester, 1440);
    expect(find.byKey(const Key('auth-split-layout')), findsOneWidget);
    expect(find.byKey(const Key('auth-form-card')), findsOneWidget);
    expect(find.byKey(const Key('auth-stage-0')), findsOneWidget);
    expect(find.byKey(const Key('auth-stage-1')), findsOneWidget);
    expect(find.byKey(const Key('auth-stage-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tablet shows stacked layout', (tester) async {
    await showAt(tester, 800);
    expect(find.byKey(const Key('auth-stacked-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile shows stacked layout', (tester) async {
    await showAt(tester, 390);
    expect(find.byKey(const Key('auth-stacked-layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
