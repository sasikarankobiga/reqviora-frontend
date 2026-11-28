class AdminProfileDetails {
  const AdminProfileDetails({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.mfaEnabled,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;
  final bool mfaEnabled;

  factory AdminProfileDetails.fromJson(Object? value) {
    final map = _map(value, 'profile');
    final email = _text(map['email'], 320);
    final displayName = _text(map['displayName'], 200);
    if (!email.contains('@') ||
        map['emailVerified'] is! bool ||
        map['mfaEnabled'] is! bool) {
      throw const FormatException('Invalid administrator profile.');
    }
    return AdminProfileDetails(
      id: _id(map['id']),
      email: email,
      displayName: displayName,
      emailVerified: map['emailVerified'] as bool,
      mfaEnabled: map['mfaEnabled'] as bool,
    );
  }
}

class AdminSessionDetails {
  const AdminSessionDetails({
    required this.id,
    required this.createdAt,
    required this.expiresAt,
    required this.isCurrent,
  });
  final String id;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isCurrent;

  factory AdminSessionDetails.fromJson(Object? value) {
    final map = _map(value, 'session');
    if (map['isCurrent'] is! bool) {
      throw const FormatException('Invalid administrator session.');
    }
    final created = _date(map['createdAt']);
    final expires = _date(map['expiresAt']);
    if (!expires.isAfter(created)) {
      throw const FormatException('Invalid administrator session lifetime.');
    }
    return AdminSessionDetails(
      id: _id(map['id']),
      createdAt: created,
      expiresAt: expires,
      isCurrent: map['isCurrent'] as bool,
    );
  }
}

class AdminSecurityEvent {
  const AdminSecurityEvent({
    required this.id,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.occurredAt,
  });
  final String id;
  final String method;
  final String path;
  final int statusCode;
  final DateTime occurredAt;

  factory AdminSecurityEvent.fromJson(Object? value) {
    final map = _map(value, 'security event');
    final status = map['statusCode'];
    if (status is! int || status < 100 || status > 599) {
      throw const FormatException('Invalid security event status.');
    }
    return AdminSecurityEvent(
      id: _id(map['id']),
      method: _text(map['method'], 16),
      path: _text(map['path'], 500),
      statusCode: status,
      occurredAt: _date(map['occurredAt']),
    );
  }
}

class AdminSecurityDetails {
  const AdminSecurityDetails({
    required this.mfaEnabled,
    required this.emailVerified,
    required this.activeSessions,
    required this.recentEvents,
  });
  final bool mfaEnabled;
  final bool emailVerified;
  final int activeSessions;
  final List<AdminSecurityEvent> recentEvents;

  factory AdminSecurityDetails.fromJson(Object? value) {
    final map = _map(value, 'security details');
    final sessions = map['activeSessions'];
    final events = map['recentEvents'];
    if (map['mfaEnabled'] is! bool ||
        map['emailVerified'] is! bool ||
        sessions is! int ||
        sessions < 0 ||
        events is! List ||
        events.length > 50) {
      throw const FormatException('Invalid administrator security details.');
    }
    return AdminSecurityDetails(
      mfaEnabled: map['mfaEnabled'] as bool,
      emailVerified: map['emailVerified'] as bool,
      activeSessions: sessions,
      recentEvents: List.unmodifiable(events.map(AdminSecurityEvent.fromJson)),
    );
  }
}

class AdminLoginHistoryEntry {
  const AdminLoginHistoryEntry({
    required this.id,
    required this.ipAddress,
    required this.deviceId,
    required this.succeeded,
    required this.otpRequired,
    required this.occurredAt,
  });
  final String id;
  final String ipAddress;
  final String deviceId;
  final bool succeeded;
  final bool otpRequired;
  final DateTime occurredAt;

  factory AdminLoginHistoryEntry.fromJson(Object? value) {
    final map = _map(value, 'login history');
    if (map['succeeded'] is! bool || map['otpRequired'] is! bool) {
      throw const FormatException('Invalid login history entry.');
    }
    return AdminLoginHistoryEntry(
      id: _id(map['id']),
      ipAddress: _text(map['ipAddress'], 100),
      deviceId: _text(map['deviceId'], 200),
      succeeded: map['succeeded'] as bool,
      otpRequired: map['otpRequired'] as bool,
      occurredAt: _date(map['occurredAt']),
    );
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
Map<Object?, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('Invalid administrator $name.');
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
      value.runes.any((character) => character < 32)) {
    throw const FormatException('Invalid text metadata.');
  }
  return value;
}

DateTime _date(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value)?.toUtc() : null;
  if (parsed == null) throw const FormatException('Invalid timestamp.');
  return parsed;
}
