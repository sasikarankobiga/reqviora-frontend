import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/billing/data/billing_repository.dart';
import 'package:reqviora_frontend/features/billing/domain/billing_models.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const paymentId = '22222222-2222-4222-8222-222222222222';

  BillingRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    return BillingRepository(api);
  }

  http.Response response(Object? value, [int status = 200]) => http.Response(
    value == null ? '' : jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> payment({
    String status = 'Pending',
    bool entitled = false,
  }) => {
    'id': paymentId,
    'orderId': 'REQ-20261127-1',
    'projectId': projectId,
    'requestedBy': '33333333-3333-4333-8333-333333333333',
    'amountMinor': 12500,
    'currency': 'USD',
    'status': status,
    'providerPaymentId': null,
    'createdAt': '2026-11-27T08:00:00Z',
    'updatedAt': '2026-11-27T08:00:00Z',
    'expiresAt': '2026-11-27T08:30:00Z',
    'entitled': entitled,
  };

  const contact = CheckoutContact(
    firstName: 'Test',
    lastName: 'Owner',
    email: 'owner@example.com',
    phone: '+94770000000',
    address: '1 Test Road',
    city: 'Colombo',
    country: 'Sri Lanka',
  );

  test('retrieves server-authoritative project pricing', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/billing/pricing');
      expect(request.url.queryParameters, {'projectId': projectId});
      return response({
        'amountMinor': 12500,
        'currency': 'USD',
        'displayAmount': '125.00',
        'gatewayEnabled': true,
        'projectOverride': true,
      });
    });
    final result = await repo.pricing(projectId);
    expect(result.amountMinor, 12500);
    expect(result.displayAmount, '125.00');
  });

  test('maps checkout contact without a client amount', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/projects/$projectId/billing/checkout');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], 'owner@example.com');
      expect(body, isNot(contains('amount')));
      expect(body, isNot(contains('currency')));
      return response({
        'paymentId': paymentId,
        'orderId': 'REQ-20261127-1',
        'actionUrl': 'https://sandbox.payhere.lk/pay/checkout',
        'fields': {
          'merchant_id': 'sandbox',
          'order_id': 'REQ-20261127-1',
          'currency': 'USD',
          'amount': '125.00',
          'hash': 'server-signature',
        },
        'expiresAt': '2026-11-27T08:30:00Z',
      });
    });
    final checkout = await repo.checkout(
      projectId: projectId,
      contact: contact,
    );
    expect(checkout.actionUrl.host, 'sandbox.payhere.lk');
    expect(checkout.fields['amount'], '125.00');
  });

  test('rejects unapproved checkout destinations and secret fields', () async {
    var includeSecret = false;
    final repo = repository(
      (request) async => response({
        'paymentId': paymentId,
        'orderId': 'REQ-20261127-1',
        'actionUrl':
            includeSecret
                ? 'https://sandbox.payhere.lk/pay/checkout'
                : 'https://evil.example/pay/checkout',
        'fields': {
          'order_id': 'REQ-20261127-1',
          'currency': 'USD',
          'amount': '125.00',
          'hash': 'server-signature',
          if (includeSecret) 'merchant_secret': 'must-not-appear',
        },
        'expiresAt': '2026-11-27T08:30:00Z',
      }),
    );
    await expectLater(
      repo.checkout(projectId: projectId, contact: contact),
      throwsFormatException,
    );
    includeSecret = true;
    await expectLater(
      repo.checkout(projectId: projectId, contact: contact),
      throwsFormatException,
    );
  });

  test('loads authoritative payment and entitlement status', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/projects/$projectId/billing/status');
      return response(payment(status: 'Succeeded', entitled: true));
    });
    final result = await repo.status(projectId);
    expect(result.status, PaymentStatus.succeeded);
    expect(result.entitled, isTrue);
  });

  test('rejects empty order IDs and malformed payment currencies', () async {
    for (final invalid in [
      {...payment(), 'orderId': ''},
      {...payment(), 'currency': 'usd'},
      {...payment(), 'currency': 'US'},
    ]) {
      final repo = repository((request) async => response(invalid));
      await expectLater(repo.status(projectId), throwsFormatException);
    }
  });

  test('loads paginated payment history', () async {
    final repo = repository((request) async {
      expect(request.url.queryParameters, {'page': '1', 'pageSize': '50'});
      return response({
        'items': [payment()],
        'page': 1,
        'pageSize': 50,
        'total': 1,
      });
    });
    final result = await repo.history(projectId);
    expect(result.total, 1);
    expect(result.items.single.amountMinor, 12500);
  });

  test('loads a single payment without trusting redirect data', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/billing/payments/$paymentId');
      return response(payment(status: 'Processing'));
    });
    expect((await repo.payment(paymentId)).status, PaymentStatus.processing);
  });

  test('submits and reads sandbox refund request contract', () async {
    var create = true;
    final repo = repository((request) async {
      expect(
        request.url.path,
        '/api/projects/$projectId/billing/payments/$paymentId/refund-request',
      );
      if (create) {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {'reason': 'service_issue'});
      } else {
        expect(request.method, 'GET');
      }
      return response({
        'paymentId': paymentId,
        'reason': 'service_issue',
        'status': 'requested',
        'requestedAt': '2026-11-27T09:00:00Z',
        'reviewedAt': null,
        'sandbox': true,
        'refundExecuted': false,
      }, create ? 201 : 200);
    });
    expect(
      (await repo.requestRefund(
        projectId: projectId,
        paymentId: paymentId,
        reason: 'service_issue',
      )).status,
      'requested',
    );
    create = false;
    expect(
      (await repo.refundStatus(
        projectId: projectId,
        paymentId: paymentId,
      )).status,
      'requested',
    );
  });

  test('rejects invalid checkout contact and refund reason locally', () async {
    final repo = repository((request) async {
      fail('Invalid request must not reach the API');
    });
    await expectLater(
      repo.checkout(
        projectId: projectId,
        contact: const CheckoutContact(
          firstName: '',
          lastName: 'Owner',
          email: 'invalid',
          phone: '1',
          address: 'A',
          city: 'C',
          country: 'L',
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.requestRefund(
        projectId: projectId,
        paymentId: paymentId,
        reason: 'arbitrary',
      ),
      throwsArgumentError,
    );
  });

  test('rejects cross-project payment histories', () async {
    final repo = repository(
      (request) async => response({
        'items': [
          {...payment(), 'projectId': paymentId},
        ],
        'page': 1,
        'pageSize': 50,
        'total': 1,
      }),
    );
    await expectLater(repo.history(projectId), throwsFormatException);
  });

  test(
    'preserves unavailable gateway and unauthorized checkout errors',
    () async {
      var status = 503;
      final repo = repository(
        (request) async => response({'title': 'Unavailable'}, status),
      );
      await expectLater(
        repo.checkout(projectId: projectId, contact: contact),
        throwsA(
          isA<ApiException>().having(
            (value) => value.statusCode,
            'status',
            503,
          ),
        ),
      );
      status = 403;
      await expectLater(
        repo.checkout(projectId: projectId, contact: contact),
        throwsA(
          isA<ApiException>().having(
            (value) => value.statusCode,
            'status',
            403,
          ),
        ),
      );
    },
  );
}
