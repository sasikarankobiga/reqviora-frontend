import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/app/widgets.dart';

void main() {
  testWidgets('Retry supports keyboard Tab and Enter', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineError(
            'Connection unavailable',
            onRetry: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('Retry is exposed to accessibility semantics', (tester) async {
    final handle = tester.ensureSemantics();
    // Dispose the semantics handle before the test completes.

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineError('Connection unavailable', onRetry: () {}),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Retry'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Error UI renders on tablet width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: InlineError('Temporary server failure', onRetry: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Temporary server failure'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
