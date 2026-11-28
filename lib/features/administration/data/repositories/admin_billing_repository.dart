import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/admin_billing_models.dart';

enum AdminPaymentStatus {
  all,
  pending,
  succeeded,
  failed,
  cancelled,
  chargedback,
}

enum AdminBillingCurrency { all, usd, lkr }

class AdminBillingRepository {
  AdminBillingRepository(this.api);
  final ApiClient api;
  final Set<String> _refundReviewsInFlight = <String>{};

  Future<AdminBillingSummary> summary(String code) {
    _requireCode(code);
    return _guarded(
      () async => AdminBillingSummary.fromJson(
        await api.post('/api/admin/billing/summary', <String, dynamic>{
          'code': code,
        }),
      ),
    );
  }

  Future<AdminPaymentPage> payments({
    required String code,
    int page = 1,
    int pageSize = 20,
    String? projectId,
    AdminPaymentStatus status = AdminPaymentStatus.all,
    AdminBillingCurrency currency = AdminBillingCurrency.all,
  }) {
    _requireCode(code);
    if (page < 1 ||
        page > 1000000 ||
        pageSize < 1 ||
        pageSize > 100 ||
        projectId != null && !_uuid.hasMatch(projectId)) {
      throw ArgumentError('Invalid billing filters.');
    }
    return _guarded(
      () async => AdminPaymentPage.fromJson(
        await api.post('/api/admin/billing/transactions', <String, dynamic>{
          'code': code,
          'page': page,
          'pageSize': pageSize,
          'projectId': projectId,
          'status': status == AdminPaymentStatus.all ? null : status.name,
          'currency': switch (currency) {
            AdminBillingCurrency.all => null,
            AdminBillingCurrency.usd => 'USD',
            AdminBillingCurrency.lkr => 'LKR',
          },
        }),
      ),
    );
  }

  Future<AdminPaymentItem> paymentDetails(String paymentId, String code) {
    _requireId(paymentId);
    _requireCode(code);
    return _guarded(() async {
      final result = AdminPaymentItem.fromJson(
        await api.post(
          '/api/admin/billing/transactions/$paymentId',
          <String, dynamic>{'code': code},
        ),
      );
      if (result.paymentId.toLowerCase() != paymentId.toLowerCase()) {
        throw const FormatException('Unexpected payment identity.');
      }
      return result;
    });
  }

  Future<AdminRefundPage> refunds({
    required String code,
    int page = 1,
    int pageSize = 20,
  }) {
    _requireCode(code);
    if (page < 1 || page > 1000000 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid refund page.');
    }
    return _guarded(
      () async => AdminRefundPage.fromJson(
        await api.post('/api/admin/billing/refunds', <String, dynamic>{
          'code': code,
          'page': page,
          'pageSize': pageSize,
        }),
      ),
    );
  }

  Future<AdminRefundItem> reviewRefund({
    required String paymentId,
    required String code,
    required String decision,
  }) async {
    _requireId(paymentId);
    _requireCode(code);
    if (!const {'reviewed', 'rejected'}.contains(decision)) {
      throw ArgumentError('Invalid refund review decision.');
    }
    if (!_refundReviewsInFlight.add(paymentId)) {
      throw StateError('A refund review is already in progress.');
    }
    try {
      return await _guarded(() async {
        return AdminRefundItem.fromJson(
          await api.post(
            '/api/admin/billing/refunds/$paymentId/review',
            <String, dynamic>{'code': code, 'decision': decision},
          ),
        );
      });
    } finally {
      _refundReviewsInFlight.remove(paymentId);
    }
  }

  Future<T> _guarded<T>(Future<T> Function() operation) async {
    final generation = authSession.generation;
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Authentication is required.');
    }
    try {
      final result = await operation();
      if (!authSession.authenticated || generation != authSession.generation) {
        throw const ApiException(401, 'The administration session changed.');
      }
      return result;
    } catch (_) {
      rethrow;
    }
  }

  void _requireCode(String value) {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) {
      throw ArgumentError(
        'A current six-digit administrator MFA code is required.',
      );
    }
  }

  void _requireId(String value) {
    if (!_uuid.hasMatch(value)) {
      throw ArgumentError('Invalid payment identifier.');
    }
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
