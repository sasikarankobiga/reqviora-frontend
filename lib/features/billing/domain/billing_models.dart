import '../../projects/data/project_members_repository.dart';

enum PaymentStatus {
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
  refunded,
  disputed;

  static PaymentStatus parse(Object? value) => switch (value
      ?.toString()
      .toLowerCase()) {
    'pending' => pending,
    'processing' => processing,
    'succeeded' => succeeded,
    'failed' => failed,
    'cancelled' => cancelled,
    'refunded' => refunded,
    'disputed' => disputed,
    _ => throw const FormatException('Unsupported payment status'),
  };

  bool get terminal =>
      const {succeeded, failed, cancelled, refunded, disputed}.contains(this);
}

class ProjectPricing {
  const ProjectPricing({
    required this.amountMinor,
    required this.currency,
    required this.displayAmount,
    required this.gatewayEnabled,
    required this.projectOverride,
  });

  final int amountMinor;
  final String currency;
  final String displayAmount;
  final bool gatewayEnabled;
  final bool projectOverride;

  factory ProjectPricing.fromJson(Map<String, dynamic> json) {
    final amount = json['amountMinor'];
    final currency = json['currency'];
    final display = json['displayAmount'];
    if (amount is! int ||
        amount < 0 ||
        currency is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        display is! String ||
        !RegExp(r'^\d+\.\d{2}$').hasMatch(display) ||
        json['gatewayEnabled'] is! bool ||
        json['projectOverride'] is! bool) {
      throw const FormatException('Invalid project pricing');
    }
    return ProjectPricing(
      amountMinor: amount,
      currency: currency,
      displayAmount: display,
      gatewayEnabled: json['gatewayEnabled'] as bool,
      projectOverride: json['projectOverride'] as bool,
    );
  }
}

class CheckoutContact {
  const CheckoutContact({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.country,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String country;

  Map<String, dynamic> toJson() => {
    'firstName': firstName.trim(),
    'lastName': lastName.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'country': country.trim(),
  };
}

class BillingCheckout {
  const BillingCheckout({
    required this.paymentId,
    required this.orderId,
    required this.actionUrl,
    required this.fields,
    required this.expiresAt,
  });

  final String paymentId;
  final String orderId;
  final Uri actionUrl;
  final Map<String, String> fields;
  final DateTime expiresAt;

  factory BillingCheckout.fromJson(Map<String, dynamic> json) {
    final paymentId = json['paymentId'];
    final orderId = json['orderId'];
    final action = Uri.tryParse(json['actionUrl']?.toString() ?? '');
    final expiresAt = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    final rawFields = json['fields'];
    if (paymentId is! String ||
        !isProjectMemberGuid(paymentId) ||
        orderId is! String ||
        orderId.trim().isEmpty ||
        orderId.length > 100 ||
        action == null ||
        action.scheme != 'https' ||
        !const {'sandbox.payhere.lk', 'www.payhere.lk'}.contains(action.host) ||
        action.path != '/pay/checkout' ||
        action.userInfo.isNotEmpty ||
        action.hasQuery ||
        action.hasFragment ||
        expiresAt == null ||
        rawFields is! Map) {
      throw const FormatException('Invalid checkout response');
    }
    final fields = <String, String>{};
    for (final entry in rawFields.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid checkout field');
      }
      fields[entry.key as String] = entry.value as String;
    }
    if (fields['order_id'] != orderId ||
        fields['currency'] == null ||
        fields['amount'] == null ||
        fields['hash'] == null ||
        fields.containsKey('merchant_secret')) {
      throw const FormatException('Incomplete checkout fields');
    }
    return BillingCheckout(
      paymentId: paymentId,
      orderId: orderId,
      actionUrl: action,
      fields: Map.unmodifiable(fields),
      expiresAt: expiresAt.toUtc(),
    );
  }
}

class PaymentDetails {
  const PaymentDetails({
    required this.id,
    required this.orderId,
    required this.projectId,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.entitled,
  });

  final String id;
  final String orderId;
  final String projectId;
  final int amountMinor;
  final String currency;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final bool entitled;

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final projectId = json['projectId'];
    final orderId = json['orderId'];
    final currency = json['currency'];
    final created = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updated = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final expires = DateTime.tryParse(json['expiresAt']?.toString() ?? '');
    if (id is! String ||
        projectId is! String ||
        !isProjectMemberGuid(id) ||
        !isProjectMemberGuid(projectId) ||
        orderId is! String ||
        orderId.trim().isEmpty ||
        orderId.length > 100 ||
        json['amountMinor'] is! int ||
        (json['amountMinor'] as int) <= 0 ||
        currency is! String ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        created == null ||
        updated == null ||
        expires == null ||
        json['entitled'] is! bool) {
      throw const FormatException('Invalid payment details');
    }
    return PaymentDetails(
      id: id,
      orderId: orderId,
      projectId: projectId,
      amountMinor: json['amountMinor'] as int,
      currency: currency,
      status: PaymentStatus.parse(json['status']),
      createdAt: created.toUtc(),
      updatedAt: updated.toUtc(),
      expiresAt: expires.toUtc(),
      entitled: json['entitled'] as bool,
    );
  }
}

class PaymentHistoryPage {
  const PaymentHistoryPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });
  final List<PaymentDetails> items;
  final int page;
  final int pageSize;
  final int total;
}

class RefundStatus {
  const RefundStatus({
    required this.paymentId,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
  });
  final String paymentId;
  final String reason;
  final String status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;

  factory RefundStatus.fromJson(Map<String, dynamic> json) {
    final paymentId = json['paymentId'];
    final requestedAt = DateTime.tryParse(
      json['requestedAt']?.toString() ?? '',
    );
    final reviewedAt =
        json['reviewedAt'] == null
            ? null
            : DateTime.tryParse(json['reviewedAt'].toString());
    if (paymentId is! String ||
        !isProjectMemberGuid(paymentId) ||
        json['reason'] is! String ||
        !const {'requested', 'reviewed', 'rejected'}.contains(json['status']) ||
        requestedAt == null ||
        (json['reviewedAt'] != null && reviewedAt == null)) {
      throw const FormatException('Invalid refund status');
    }
    return RefundStatus(
      paymentId: paymentId,
      reason: json['reason'] as String,
      status: json['status'] as String,
      requestedAt: requestedAt.toUtc(),
      reviewedAt: reviewedAt?.toUtc(),
    );
  }
}
