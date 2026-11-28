enum AdminMcpGrantState { all, active, expired, revoked }

class AdminMcpGrant {
  const AdminMcpGrant({
    required this.id,
    required this.projectId,
    required this.approvedRevisionId,
    required this.ownerId,
    required this.createdAt,
    required this.expiresAt,
    required this.state,
    this.revokedAt,
    this.revokedBy,
    this.revocationReason,
  });

  final String id;
  final String projectId;
  final String approvedRevisionId;
  final String ownerId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String? revocationReason;
  final AdminMcpGrantState state;

  factory AdminMcpGrant.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid MCP grant.');
    final state = switch (value['state']) {
      'active' => AdminMcpGrantState.active,
      'expired' => AdminMcpGrantState.expired,
      'revoked' => AdminMcpGrantState.revoked,
      _ => null,
    };
    final createdAt = _date(value['createdAt']);
    final expiresAt = _date(value['expiresAt']);
    if (state == null || createdAt == null || expiresAt == null) {
      throw const FormatException('Invalid MCP grant metadata.');
    }
    return AdminMcpGrant(
      id: _id(value['id']),
      projectId: _id(value['projectId']),
      approvedRevisionId: _id(value['approvedRevisionId']),
      ownerId: _id(value['ownerId']),
      createdAt: createdAt,
      expiresAt: expiresAt,
      revokedAt: _nullableDate(value['revokedAt']),
      revokedBy: _nullableId(value['revokedBy']),
      revocationReason: _nullableText(value['revocationReason'], 500),
      state: state,
    );
  }
}

class AdminMcpGrantPage {
  const AdminMcpGrantPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int total;
  final List<AdminMcpGrant> items;

  factory AdminMcpGrantPage.fromJson(Object? value) {
    if (value is! Map || value['items'] is! List) {
      throw const FormatException('Invalid MCP grant page.');
    }
    final page = value['page'];
    final pageSize = value['pageSize'];
    final total = value['total'];
    if (page is! int ||
        page < 1 ||
        pageSize is! int ||
        pageSize < 1 ||
        pageSize > 100 ||
        total is! int ||
        total < 0) {
      throw const FormatException('Invalid MCP pagination.');
    }
    return AdminMcpGrantPage(
      page: page,
      pageSize: pageSize,
      total: total,
      items: List.unmodifiable(
        (value['items'] as List).map(AdminMcpGrant.fromJson),
      ),
    );
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String _id(Object? value) {
  if (value is! String || !_uuid.hasMatch(value)) {
    throw const FormatException('Invalid identifier.');
  }
  return value;
}

String? _nullableId(Object? value) => value == null ? null : _id(value);

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

DateTime? _nullableDate(Object? value) {
  if (value == null) return null;
  final parsed = _date(value);
  if (parsed == null) throw const FormatException('Invalid timestamp.');
  return parsed;
}

String? _nullableText(Object? value, int maximum) {
  if (value == null) return null;
  if (value is! String || value.length > maximum) {
    throw const FormatException('Invalid text metadata.');
  }
  return value;
}
