import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/billing/data/billing_repository.dart';
import 'package:reqviora_frontend/features/billing/domain/billing_models.dart';
import 'package:reqviora_frontend/features/billing/domain/hosted_checkout_port.dart';
import 'package:reqviora_frontend/features/billing/presentation/billing_checkout_dialog.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const paymentId = '22222222-2222-4222-8222-222222222222';

class FakeHostedCheckout implements HostedCheckoutPort {
  BillingCheckout? submitted;

  @override
  void submit(BillingCheckout checkout) => submitted = checkout;
}

void main() {
  const pricing = ProjectPricing(
    amountMinor: 12500,
    currency: 'USD',
    displayAmount: '125.00',
    gatewayEnabled: true,
    projectOverride: false,
  );

  http.Response response(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  BillingRepository billing(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    return BillingRepository(api);
  }

  Future<void> pumpCheckout(
    WidgetTester tester,
    Size size,
    BillingRepository repository,
    FakeHostedCheckout launcher,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BillingCheckoutDialog(
            projectId: projectId,
            pricing: pricing,
            repository: repository,
            hostedCheckout: launcher,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(320, 640),
    Size(375, 812),
    Size(390, 844),
    Size(768, 1024),
    Size(1024, 768),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('checkout dialog fits ${size.width}x${size.height}', (
      tester,
    ) async {
      final repository = billing((_) async => response({}));
      await pumpCheckout(tester, size, repository, FakeHostedCheckout());
      expect(find.text('Secure PayHere Checkout'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(7));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'checkout prevents duplicate submissions and launches verified form once',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final repository = billing((request) {
        calls++;
        return pending.future;
      });
      final launcher = FakeHostedCheckout();
      await pumpCheckout(tester, const Size(768, 1024), repository, launcher);

      final values = [
        'Test',
        'Owner',
        'owner@example.com',
        '+94770000000',
        '1 Test Road',
        'Colombo',
        'Sri Lanka',
      ];
      for (var index = 0; index < values.length; index++) {
        await tester.enterText(
          find.byType(TextFormField).at(index),
          values[index],
        );
      }
      final button = find.byKey(const ValueKey('start-payhere-checkout'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      expect(calls, 1);

      pending.complete(
        response({
          'paymentId': paymentId,
          'orderId': 'REQ-1',
          'actionUrl': 'https://sandbox.payhere.lk/pay/checkout',
          'fields': {
            'order_id': 'REQ-1',
            'currency': 'USD',
            'amount': '125.00',
            'hash': 'signed',
          },
          'expiresAt': '2026-11-27T10:00:00Z',
        }),
      );
      await tester.pumpAndSettle();
      expect(launcher.submitted?.paymentId, paymentId);
    },
  );
}
