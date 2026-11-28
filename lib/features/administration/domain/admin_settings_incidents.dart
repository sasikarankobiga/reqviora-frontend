import '../../../core/network/api_client.dart';

const documentUploadSettingKey = 'document-upload-max-bytes';
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

int _int(Map<Object?, Object?> j, String k, {int min = 0}) {
  final v = j[k];
  if (v is! int || v < min)
    throw const ApiException(502, 'Invalid administration response.');
  return v;
}

String _string(Map<Object?, Object?> j, String k, {int max = 1000}) {
  final v = j[k];
  if (v is! String || v.isEmpty || v.length > max)
    throw const ApiException(502, 'Invalid administration response.');
  return v;
}

String? _optionalString(Map<Object?, Object?> j, String k, {int max = 1000}) {
  final v = j[k];
  if (v == null) return null;
  if (v is! String || v.length > max)
    throw const ApiException(502, 'Invalid administration response.');
  return v;
}

DateTime _date(Map<Object?, Object?> j, String k) {
  final parsed = DateTime.tryParse(_string(j, k));
  if (parsed == null)
    throw const ApiException(502, 'Invalid administration timestamp.');
  return parsed.toUtc();
}

DateTime? _optionalDate(Map<Object?, Object?> j, String k) {
  final v = j[k];
  if (v == null) return null;
  if (v is! String || DateTime.tryParse(v) == null)
    throw const ApiException(502, 'Invalid administration timestamp.');
  return DateTime.parse(v).toUtc();
}

class PlatformSetting {
  const PlatformSetting({
    required this.key,
    required this.value,
    required this.revision,
    required this.minimum,
    required this.maximum,
  });
  final String key;
  final int value;
  final int revision;
  final int minimum;
  final int maximum;
  factory PlatformSetting.fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>)
      throw const ApiException(502, 'Invalid platform setting.');
    final result = PlatformSetting(
      key: _string(raw, 'key'),
      value: _int(raw, 'value'),
      revision: _int(raw, 'revision'),
      minimum: _int(raw, 'minimum'),
      maximum: _int(raw, 'maximum', min: 1),
    );
    if (result.key != documentUploadSettingKey ||
        result.value < result.minimum ||
        result.value > result.maximum ||
        result.minimum > result.maximum)
      throw const ApiException(502, 'Unsupported platform setting.');
    return result;
  }
}

class SettingHistoryEntry {
  const SettingHistoryEntry({
    required this.revision,
    required this.previousValue,
    required this.value,
    required this.changedBy,
    required this.changedAt,
    required this.reason,
    required this.rolledBackTo,
  });
  final int revision;
  final int previousValue;
  final int value;
  final String changedBy;
  final DateTime changedAt;
  final String reason;
  final int? rolledBackTo;
  factory SettingHistoryEntry.fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?> || raw['rolledBackTo'] is! int?)
      throw const ApiException(502, 'Invalid setting history.');
    final actor = _string(raw, 'changedBy');
    if (!_uuid.hasMatch(actor))
      throw const ApiException(502, 'Invalid setting history actor.');
    return SettingHistoryEntry(
      revision: _int(raw, 'revision', min: 1),
      previousValue: _int(raw, 'previousValue'),
      value: _int(raw, 'value'),
      changedBy: actor,
      changedAt: _date(raw, 'changedAt'),
      reason: _string(raw, 'reason', max: 500),
      rolledBackTo: raw['rolledBackTo'] as int?,
    );
  }
}

enum IncidentPriority { low, medium, high, critical }

enum IncidentStatus { open, inProgress, resolved, closed }

String priorityWire(IncidentPriority v) =>
    '${v.name[0].toUpperCase()}${v.name.substring(1)}';
String statusWire(IncidentStatus v) =>
    v == IncidentStatus.inProgress
        ? 'InProgress'
        : '${v.name[0].toUpperCase()}${v.name.substring(1)}';
IncidentPriority _priority(Object? v) => IncidentPriority.values.firstWhere(
  (e) => priorityWire(e) == v,
  orElse: () => throw const ApiException(502, 'Invalid incident priority.'),
);
IncidentStatus _status(Object? v) => IncidentStatus.values.firstWhere(
  (e) => statusWire(e) == v,
  orElse: () => throw const ApiException(502, 'Invalid incident status.'),
);

class IncidentDetails {
  const IncidentDetails({
    required this.id,
    required this.reference,
    required this.category,
    required this.priority,
    required this.status,
    required this.reporterId,
    required this.assignedAdminId,
    required this.correlationId,
    required this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.closedAt,
    required this.concurrencyToken,
  });
  final String id, reference, category, reporterId, concurrencyToken;
  final IncidentPriority priority;
  final IncidentStatus status;
  final String? assignedAdminId, correlationId, resolutionNotes;
  final DateTime createdAt, updatedAt;
  final DateTime? resolvedAt, closedAt;
  factory IncidentDetails.fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>)
      throw const ApiException(502, 'Invalid incident.');
    final ids = [
      _string(raw, 'id'),
      _string(raw, 'reporterId'),
      _string(raw, 'concurrencyToken'),
    ];
    final assigned = _optionalString(raw, 'assignedAdminId');
    if (ids.any((id) => !_uuid.hasMatch(id)) ||
        assigned != null && !_uuid.hasMatch(assigned))
      throw const ApiException(502, 'Invalid incident identity.');
    return IncidentDetails(
      id: ids[0],
      reference: _string(raw, 'reference', max: 30),
      category: _string(raw, 'category', max: 80),
      priority: _priority(raw['priority']),
      status: _status(raw['status']),
      reporterId: ids[1],
      assignedAdminId: assigned,
      correlationId: _optionalString(raw, 'correlationId', max: 100),
      resolutionNotes: _optionalString(raw, 'resolutionNotes'),
      createdAt: _date(raw, 'createdAt'),
      updatedAt: _date(raw, 'updatedAt'),
      resolvedAt: _optionalDate(raw, 'resolvedAt'),
      closedAt: _optionalDate(raw, 'closedAt'),
      concurrencyToken: ids[2],
    );
  }
}

class IncidentPage {
  const IncidentPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });
  final List<IncidentDetails> items;
  final int page, pageSize, total;
  factory IncidentPage.fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?> || raw['items'] is! List)
      throw const ApiException(502, 'Invalid incident page.');
    final items = (raw['items'] as List).map(IncidentDetails.fromJson).toList();
    final size = _int(raw, 'pageSize', min: 1), total = _int(raw, 'total');
    if (size > 100 || items.length > size || items.length > total)
      throw const ApiException(502, 'Invalid incident pagination.');
    return IncidentPage(
      items: List.unmodifiable(items),
      page: _int(raw, 'page', min: 1),
      pageSize: size,
      total: total,
    );
  }
}

class IncidentHistoryEntry {
  const IncidentHistoryEntry({
    required this.action,
    required this.previousValue,
    required this.newValue,
    required this.notes,
    required this.changedBy,
    required this.changedAt,
  });
  final String action, changedBy;
  final String? previousValue, newValue, notes;
  final DateTime changedAt;
  factory IncidentHistoryEntry.fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>)
      throw const ApiException(502, 'Invalid incident history.');
    final actor = _string(raw, 'changedBy');
    if (!_uuid.hasMatch(actor))
      throw const ApiException(502, 'Invalid incident history.');
    return IncidentHistoryEntry(
      action: _string(raw, 'action'),
      previousValue: _optionalString(raw, 'previousValue'),
      newValue: _optionalString(raw, 'newValue'),
      notes: _optionalString(raw, 'notes'),
      changedBy: actor,
      changedAt: _date(raw, 'changedAt'),
    );
  }
}

class IncidentSummary {
  const IncidentSummary({
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
    required this.critical,
    required this.unassigned,
    required this.total,
  });
  final int open, inProgress, resolved, closed, critical, unassigned, total;
  factory IncidentSummary.fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>)
      throw const ApiException(502, 'Invalid incident summary.');
    return IncidentSummary(
      open: _int(raw, 'open'),
      inProgress: _int(raw, 'inProgress'),
      resolved: _int(raw, 'resolved'),
      closed: _int(raw, 'closed'),
      critical: _int(raw, 'critical'),
      unassigned: _int(raw, 'unassigned'),
      total: _int(raw, 'total'),
    );
  }
}
