class AdminPaymentItem {
  const AdminPaymentItem({
    required this.paymentId,
    required this.projectId,
    required this.payerId,
    required this.orderReference,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  final String paymentId;
  final String projectId;
  final String payerId;
  final String orderReference;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminPaymentItem.fromJson(Object? value) {
    final map = _map(value, 'payment');
    final amount = map['amount'];
    final currency = map['currency'];
    final status = map['status'];
    if (amount is! num ||
        !amount.isFinite ||
        amount < 0 ||
        currency is! String ||
        !const {'USD', 'LKR'}.contains(currency) ||
        status is! String ||
        !const {
          'pending',
          'succeeded',
          'failed',
          'cancelled',
          'chargedback',
        }.contains(status)) {
      throw const FormatException('Invalid payment metadata.');
    }
    return AdminPaymentItem(
      paymentId: _id(map['paymentId']),
      projectId: _id(map['projectId']),
      payerId: _id(map['payerId']),
      orderReference: _text(map['orderReference'], 200),
      amount: amount.toDouble(),
      currency: currency,
      status: status,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }
}

class AdminPaymentPage {
  const AdminPaymentPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });
  final int page;
  final int pageSize;
  final int total;
  final List<AdminPaymentItem> items;

  factory AdminPaymentPage.fromJson(Object? value) {
    final map = _map(value, 'payment page');
    final page = map['page'];
    final size = map['pageSize'];
    final total = map['total'];
    final items = map['items'];
    if (page is! int ||
        page < 1 ||
        size is! int ||
        size < 1 ||
        size > 100 ||
        total is! int ||
        total < 0 ||
        items is! List) {
      throw const FormatException('Invalid payment pagination.');
    }
    final parsed = items.map(AdminPaymentItem.fromJson).toList(growable: false);
    if (parsed.length > size ||
        parsed.length > total ||
        parsed.map((item) => item.paymentId.toLowerCase()).toSet().length !=
            parsed.length) {
      throw const FormatException('Invalid payment collection.');
    }
    return AdminPaymentPage(
      page: page,
      pageSize: size,
      total: total,
      items: List.unmodifiable(parsed),
    );
  }
}

class AdminCurrencySummary {
  const AdminCurrencySummary({
    required this.currency,
    required this.totalOrders,
    required this.successfulOrders,
    required this.pendingOrders,
    required this.failedOrders,
    required this.cancelledOrders,
    required this.chargebackOrders,
    required this.successfulOrderAmount,
    required this.chargebackAmount,
  });
  final String currency;
  final int totalOrders;
  final int successfulOrders;
  final int pendingOrders;
  final int failedOrders;
  final int cancelledOrders;
  final int chargebackOrders;
  final double successfulOrderAmount;
  final double chargebackAmount;

  factory AdminCurrencySummary.fromJson(Object? value) {
    final map = _map(value, 'billing summary');
    int count(String name) {
      final value = map[name];
      if (value is! int || value < 0) {
        throw const FormatException('Invalid billing count.');
      }
      return value;
    }

    double amount(String name) {
      final value = map[name];
      if (value is! num || !value.isFinite || value < 0) {
        throw const FormatException('Invalid billing amount.');
      }
      return value.toDouble();
    }

    final currency = map['currency'];
    if (currency is! String || !const {'USD', 'LKR'}.contains(currency)) {
      throw const FormatException('Invalid billing currency.');
    }
    final result = AdminCurrencySummary(
      currency: currency,
      totalOrders: count('totalOrders'),
      successfulOrders: count('successfulOrders'),
      pendingOrders: count('pendingOrders'),
      failedOrders: count('failedOrders'),
      cancelledOrders: count('cancelledOrders'),
      chargebackOrders: count('chargebackOrders'),
      successfulOrderAmount: amount('successfulOrderAmount'),
      chargebackAmount: amount('chargebackAmount'),
    );
    if (result.successfulOrders +
            result.pendingOrders +
            result.failedOrders +
            result.cancelledOrders +
            result.chargebackOrders !=
        result.totalOrders) {
      throw const FormatException('Inconsistent billing summary.');
    }
    return result;
  }
}

class AdminBillingSummary {
  const AdminBillingSummary({
    required this.sandbox,
    required this.accountingReport,
    required this.currencies,
  });
  final bool sandbox;
  final bool accountingReport;
  final List<AdminCurrencySummary> currencies;

  factory AdminBillingSummary.fromJson(Object? value) {
    final map = _map(value, 'billing summary envelope');
    if (map['sandbox'] is! bool ||
        map['accountingReport'] is! bool ||
        map['currencies'] is! List) {
      throw const FormatException('Invalid billing summary envelope.');
    }
    final currencies = (map['currencies'] as List)
        .map(AdminCurrencySummary.fromJson)
        .toList(growable: false);
    if (currencies.map((item) => item.currency).toSet().length !=
        currencies.length) {
      throw const FormatException('Duplicate billing currency.');
    }
    return AdminBillingSummary(
      sandbox: map['sandbox'] as bool,
      accountingReport: map['accountingReport'] as bool,
      currencies: List.unmodifiable(currencies),
    );
  }
}

class AdminRefundItem {
  const AdminRefundItem({
    required this.paymentId,
    required this.reason,
    required this.status,
    required this.requestedAt,
    required this.sandbox,
    required this.refundExecuted,
    this.reviewedAt,
  });
  final String paymentId;
  final String reason;
  final String status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final bool sandbox;
  final bool refundExecuted;

  factory AdminRefundItem.fromJson(Object? value) {
    final map = _map(value, 'refund');
    if (map['sandbox'] is! bool || map['refundExecuted'] is! bool) {
      throw const FormatException('Invalid refund metadata.');
    }
    return AdminRefundItem(
      paymentId: _id(map['paymentId']),
      reason: _text(map['reason'], 100),
      status: _text(map['status'], 40),
      requestedAt: _date(map['requestedAt']),
      reviewedAt: _nullableDate(map['reviewedAt']),
      sandbox: map['sandbox'] as bool,
      refundExecuted: map['refundExecuted'] as bool,
    );
  }
}

class AdminRefundPage {
  const AdminRefundPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });
  final int page;
  final int pageSize;
  final int total;
  final List<AdminRefundItem> items;
  factory AdminRefundPage.fromJson(Object? value) {
    final map = _map(value, 'refund page');
    final page = map['page'];
    final size = map['pageSize'];
    final total = map['total'];
    final items = map['items'];
    if (page is! int ||
        page < 1 ||
        size is! int ||
        size < 1 ||
        size > 100 ||
        total is! int ||
        total < 0 ||
        items is! List) {
      throw const FormatException('Invalid refund pagination.');
    }
    return AdminRefundPage(
      page: page,
      pageSize: size,
      total: total,
      items: List.unmodifiable(items.map(AdminRefundItem.fromJson)),
    );
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
Map<Object?, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('Invalid $name response.');
  return value;
}

String _id(Object? value) {
  if (value is! String || !_uuid.hasMatch(value)) {
    throw const FormatException('Invalid identifier.');
  }
  return value;
}

String _text(Object? value, int maximum) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maximum ||
      value.runes.any((c) => c < 32)) {
    throw const FormatException('Invalid text metadata.');
  }
  return value;
}

DateTime _date(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value)?.toUtc() : null;
  if (parsed == null) throw const FormatException('Invalid timestamp.');
  return parsed;
}

DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);
