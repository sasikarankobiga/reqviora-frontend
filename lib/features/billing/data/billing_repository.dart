import '../../../core/network/api_client.dart';
import '../../projects/data/project_members_repository.dart';
import '../domain/billing_models.dart';

class BillingRepository {
  const BillingRepository(this.api);

  final ApiClient api;

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid billing response');
    }
    return Map<String, dynamic>.from(value);
  }

  String _project(String projectId) {
    if (!isProjectMemberGuid(projectId)) {
      throw ArgumentError('Invalid project ID');
    }
    return '/api/projects/$projectId/billing';
  }

  Future<ProjectPricing> pricing(String projectId) async {
    _project(projectId);
    return ProjectPricing.fromJson(
      _object(await api.get('/api/billing/pricing?projectId=$projectId')),
    );
  }

  Future<BillingCheckout> checkout({
    required String projectId,
    required CheckoutContact contact,
  }) async {
    final values = contact.toJson();
    final limits = {
      'firstName': 100,
      'lastName': 100,
      'email': 320,
      'phone': 40,
      'address': 300,
      'city': 100,
      'country': 100,
    };
    for (final entry in limits.entries) {
      final value = values[entry.key] as String;
      if (value.isEmpty ||
          value.length > entry.value ||
          value.runes.any((code) => code < 32)) {
        throw ArgumentError('Invalid checkout contact');
      }
    }
    if (!RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(values['email'] as String)) {
      throw ArgumentError('Invalid checkout email');
    }
    final result = BillingCheckout.fromJson(
      _object(await api.post('${_project(projectId)}/checkout', values)),
    );
    return result;
  }

  Future<PaymentDetails> status(String projectId) async {
    final result = PaymentDetails.fromJson(
      _object(await api.get('${_project(projectId)}/status')),
    );
    if (result.projectId.toLowerCase() != projectId.toLowerCase()) {
      throw const FormatException('Payment belongs to another project');
    }
    return result;
  }

  Future<PaymentDetails> payment(String paymentId) async {
    if (!isProjectMemberGuid(paymentId)) {
      throw ArgumentError('Invalid payment ID');
    }
    final result = PaymentDetails.fromJson(
      _object(await api.get('/api/billing/payments/$paymentId')),
    );
    if (result.id.toLowerCase() != paymentId.toLowerCase()) {
      throw const FormatException('Unexpected payment response');
    }
    return result;
  }

  Future<PaymentHistoryPage> history(
    String projectId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid payment history page');
    }
    final raw = _object(
      await api.get(
        '${_project(projectId)}/history?page=$page&pageSize=$pageSize',
      ),
    );
    final rawItems = raw['items'];
    if (raw['page'] != page ||
        raw['pageSize'] != pageSize ||
        raw['total'] is! int ||
        (raw['total'] as int) < 0 ||
        rawItems is! List) {
      throw const FormatException('Invalid payment history');
    }
    final items = rawItems
        .map((item) {
          final payment = PaymentDetails.fromJson(_object(item));
          if (payment.projectId.toLowerCase() != projectId.toLowerCase()) {
            throw const FormatException('Cross-project payment response');
          }
          return payment;
        })
        .toList(growable: false);
    if (items.length > raw['total'] ||
        items.map((item) => item.id.toLowerCase()).toSet().length !=
            items.length) {
      throw const FormatException('Invalid payment collection');
    }
    return PaymentHistoryPage(
      items: List.unmodifiable(items),
      page: page,
      pageSize: pageSize,
      total: raw['total'] as int,
    );
  }

  Future<RefundStatus> requestRefund({
    required String projectId,
    required String paymentId,
    required String reason,
  }) async {
    if (!isProjectMemberGuid(paymentId) ||
        !const {
          'duplicate_payment',
          'service_issue',
          'other',
        }.contains(reason)) {
      throw ArgumentError('Invalid refund request');
    }
    return RefundStatus.fromJson(
      _object(
        await api.post(
          '${_project(projectId)}/payments/$paymentId/refund-request',
          {'reason': reason},
        ),
      ),
    );
  }

  Future<RefundStatus> refundStatus({
    required String projectId,
    required String paymentId,
  }) async {
    if (!isProjectMemberGuid(paymentId)) {
      throw ArgumentError('Invalid payment ID');
    }
    return RefundStatus.fromJson(
      _object(
        await api.get(
          '${_project(projectId)}/payments/$paymentId/refund-request',
        ),
      ),
    );
  }
}
