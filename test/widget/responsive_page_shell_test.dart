import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/shared/layouts/responsive_page_shell.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_tokens.dart';

void main() {
  Future<void> pumpShellAtWidth(
    WidgetTester tester,
    double width,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsivePageShell(
            child: Text('Responsive REQVIORA content'),
          ),
        ),
      ),
    );
  }

  testWidgets('Mobile layout uses compact padding', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShellAtWidth(tester, 390);

    final padding = tester.widget<Padding>(
      find.byKey(const Key('reqviora-shell-padding')),
    );

    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
    expect(find.text('Responsive REQVIORA content'), findsOneWidget);
  });

  testWidgets('Tablet layout uses medium padding', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShellAtWidth(tester, 800);

    final padding = tester.widget<Padding>(
      find.byKey(const Key('reqviora-shell-padding')),
    );

    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    );
  });

  testWidgets('Desktop layout constrains content width',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShellAtWidth(tester, 1440);

    final padding = tester.widget<Padding>(
      find.byKey(const Key('reqviora-shell-padding')),
    );

    final content = tester.widget<ConstrainedBox>(
      find.byKey(const Key('reqviora-shell-content')),
    );

    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
    );
    expect(
      content.constraints.maxWidth,
      ReqvioraTokens.maxContentWidth,
    );
  });
}