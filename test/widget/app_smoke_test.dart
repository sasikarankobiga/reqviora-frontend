import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/app/app.dart';

void main() {
  testWidgets('REQVIORA placeholder app renders correctly', (tester) async {
    await tester.pumpWidget(const ReqvioraApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    expect(
      find.text('REQVIORA • From Requirements to Reality'),
      findsOneWidget,
    );

    final app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );

    expect(app.title, 'REQVIORA');
  });
}