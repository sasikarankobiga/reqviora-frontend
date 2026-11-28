import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_billing_repository.dart';

const paymentId = '11111111-1111-4111-8111-111111111111';
const projectId = '22222222-2222-4222-8222-222222222222';
const payerId = '33333333-3333-4333-8333-333333333333';

Map<String, Object?> payment() => {
  'paymentId': paymentId,
  'projectId': projectId,
  'payerId': payerId,
  'orderReference': 'ORDER-1',
  'amount': 1250.0,
  'currency': 'LKR',
  'status': 'succeeded',
  'createdAt': '2026-11-20T10:00:00Z',
  'updatedAt': '2026-11-20T10:05:00Z',
  'merchantSecret': 'never-retain',
};
Map<String, Object?> refund({String status = 'requested'}) => {
  'paymentId': paymentId,
  'reason': 'service_issue',
  'status': status,
  'requestedAt': '2026-11-21T10:00:00Z',
  'reviewedAt': status == 'requested' ? null : '2026-11-22T10:00:00Z',
  'sandbox': true,
  'refundExecuted': false,
};

void main() {
  setUp(() => authSession.signIn('admin-token'));
  tearDown(authSession.signOut);

  test('keeps currency summaries separate and server authoritative', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(jsonDecode(request.body), {'code': '123456'});
        return http.Response(
          jsonEncode({
            'sandbox': true,
            'accountingReport': false,
            'currencies': [
              {
                'currency': 'LKR',
                'totalOrders': 3,
                'successfulOrders': 1,
                'pendingOrders': 1,
                'failedOrders': 1,
                'cancelledOrders': 0,
                'chargebackOrders': 0,
                'successfulOrderAmount': 1250,
                'chargebackAmount': 0,
              },
              {
                'currency': 'USD',
                'totalOrders': 1,
                'successfulOrders': 1,
                'pendingOrders': 0,
                'failedOrders': 0,
                'cancelledOrders': 0,
                'chargebackOrders': 0,
                'successfulOrderAmount': 10,
                'chargebackAmount': 0,
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final result = await AdminBillingRepository(api).summary('123456');
    expect(result.currencies.map((item) => item.currency), ['LKR', 'USD']);
    expect(result.accountingReport, isFalse);
  });

  test(
    'payment directory sends supported filters and pagination only',
    () async {
      final api = ApiClient(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['projectId'], projectId);
          expect(body['status'], 'succeeded');
          expect(body['currency'], 'LKR');
          expect(body.containsKey('search'), isFalse);
          return http.Response(
            jsonEncode({
              'page': 2,
              'pageSize': 20,
              'total': 21,
              'items': [payment()],
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      final page = await AdminBillingRepository(api).payments(
        code: '123456',
        page: 2,
        projectId: projectId,
        status: AdminPaymentStatus.succeeded,
        currency: AdminBillingCurrency.lkr,
      );
      expect(page.items.single.paymentId, paymentId);
      expect(page.items.single.toString(), isNot(contains('never-retain')));
    },
  );

  test('payment details require fresh MFA and matching identity', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/admin/billing/transactions/$paymentId');
        return http.Response(jsonEncode(payment()), 200);
      }),
    );
    addTearDown(api.dispose);
    expect(
      (await AdminBillingRepository(
        api,
      ).paymentDetails(paymentId, '123456')).status,
      'succeeded',
    );
  });

  test(
    'refund list and review preserve sandbox non-execution semantics',
    () async {
      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/refunds')) {
            return http.Response(
              jsonEncode({
                'page': 1,
                'pageSize': 20,
                'total': 1,
                'items': [refund()],
              }),
              200,
            );
          }
          expect(jsonDecode(request.body), {
            'code': '123456',
            'decision': 'reviewed',
          });
          return http.Response(jsonEncode(refund(status: 'reviewed')), 200);
        }),
      );
      addTearDown(api.dispose);
      final repository = AdminBillingRepository(api);
      expect(
        (await repository.refunds(code: '123456')).items.single.refundExecuted,
        isFalse,
      );
      final reviewed = await repository.reviewRefund(
        paymentId: paymentId,
        code: '123456',
        decision: 'reviewed',
      );
      expect(reviewed.status, 'reviewed');
      expect(reviewed.refundExecuted, isFalse);
    },
  );

  test(
    'duplicate refund review is prevented while request is active',
    () async {
      final response = Completer<http.Response>();
      final api = ApiClient(MockClient((_) => response.future));
      addTearDown(api.dispose);
      final repository = AdminBillingRepository(api);
      final first = repository.reviewRefund(
        paymentId: paymentId,
        code: '123456',
        decision: 'reviewed',
      );
      await expectLater(
        repository.reviewRefund(
          paymentId: paymentId,
          code: '123456',
          decision: 'reviewed',
        ),
        throwsStateError,
      );
      response.complete(
        http.Response(jsonEncode(refund(status: 'reviewed')), 200),
      );
      await first;
    },
  );

  test('invalid MFA and filters never reach backend', () async {
    var calls = 0;
    final api = ApiClient(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.dispose);
    final repository = AdminBillingRepository(api);
    expect(() => repository.summary('123'), throwsArgumentError);
    expect(
      () => repository.payments(code: '123456', projectId: 'bad'),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('MFA denial and backend unavailability are preserved', () async {
    final statuses = [401, 503];
    final api = ApiClient(
      MockClient((_) async => http.Response('{}', statuses.removeAt(0))),
    );
    addTearDown(api.dispose);
    final repository = AdminBillingRepository(api);
    await expectLater(
      repository.summary('123456'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    await expectLater(
      repository.summary('123456'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
  });
}
