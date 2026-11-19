import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_theme.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_tokens.dart';

void main() {
  testWidgets('REQVIORA theme applies provisional design tokens',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ReqvioraTheme.light,
        home: const Scaffold(
          body: Text('REQVIORA theme test'),
        ),
      ),
    );

    final context = tester.element(
      find.text('REQVIORA theme test'),
    );

    final theme = Theme.of(context);

    expect(theme.colorScheme.primary, ReqvioraTokens.accentPurple);
    expect(theme.scaffoldBackgroundColor, ReqvioraTokens.canvas);
    expect(theme.useMaterial3, isTrue);
    expect(
      theme.materialTapTargetSize,
      MaterialTapTargetSize.padded,
    );
    expect(find.text('REQVIORA theme test'), findsOneWidget);
  });

  testWidgets('REQVIORA theme supports scaled text',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ReqvioraTheme.light,
        home: const Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(2),
            ),
            child: Text('Readable content'),
          ),
        ),
      ),
    );

    final context = tester.element(find.text('Readable content'));

    expect(
      MediaQuery.textScalerOf(context).scale(16),
      32,
    );
    expect(find.text('Readable content'), findsOneWidget);
  });
}