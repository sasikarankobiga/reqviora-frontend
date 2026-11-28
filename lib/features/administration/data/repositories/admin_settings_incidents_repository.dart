import '../../../../core/network/api_client.dart';
import '../../domain/admin_settings_incidents.dart';

class AdminSettingsIncidentsRepository {
  const AdminSettingsIncidentsRepository(this.api);
  final ApiClient api;
  Future<List<PlatformSetting>> settings() async {
    final raw = await api.get('/api/admin/settings');
    if (raw is! List) throw const ApiException(502, 'Invalid settings list.');
    return List.unmodifiable(raw.map(PlatformSetting.fromJson));
  }

  Future<List<SettingHistoryEntry>> settingHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    _page(page, pageSize);
    final raw = await api.get(
      '/api/admin/settings/$documentUploadSettingKey/history?page=$page&pageSize=$pageSize',
    );
    if (raw is! List) throw const ApiException(502, 'Invalid setting history.');
    return List.unmodifiable(raw.map(SettingHistoryEntry.fromJson));
  }

  Future<PlatformSetting> updateSetting({
    required int value,
    required int expectedRevision,
    required String reason,
  }) async {
    _reason(reason);
    return PlatformSetting.fromJson(
      await api.put('/api/admin/settings/$documentUploadSettingKey', {
        'value': value,
        'expectedRevision': expectedRevision,
        'reason': reason.trim(),
      }),
    );
  }

  Future<PlatformSetting> rollbackSetting({
    required int targetRevision,
    required int expectedRevision,
    required String reason,
  }) async {
    _reason(reason);
    if (targetRevision < 1 || targetRevision >= expectedRevision) {
      throw ArgumentError('Select an older revision.');
    }
    return PlatformSetting.fromJson(
      await api.post('/api/admin/settings/$documentUploadSettingKey/rollback', {
        'targetRevision': targetRevision,
        'expectedRevision': expectedRevision,
        'reason': reason.trim(),
      }),
    );
  }

  Future<(IncidentPage, IncidentSummary)> incidents({
    String? search,
    String? category,
    IncidentPriority? priority,
    IncidentStatus? status,
    String? assignedAdminId,
    int page = 1,
    int pageSize = 20,
  }) async {
    _page(page, pageSize);
    if (assignedAdminId != null && !_uuid.hasMatch(assignedAdminId)) {
      throw ArgumentError('Invalid administrator ID.');
    }
    final q = {
      'page': '$page',
      'pageSize': '$pageSize',
      if (search?.trim().isNotEmpty ?? false) 'search': search!.trim(),
      if (category?.trim().isNotEmpty ?? false) 'category': category!.trim(),
      if (priority != null) 'priority': priorityWire(priority),
      if (status != null) 'status': statusWire(status),
      if (assignedAdminId != null) 'assignedAdminId': assignedAdminId,
    };
    final values = await Future.wait([
      api.get(Uri(path: '/api/admin/incidents', queryParameters: q).toString()),
      api.get('/api/admin/incidents/summary'),
    ]);
    return (
      IncidentPage.fromJson(values[0]),
      IncidentSummary.fromJson(values[1]),
    );
  }

  Future<(IncidentDetails, List<IncidentHistoryEntry>)> incident(
    String id,
  ) async {
    _id(id);
    final v = await Future.wait([
      api.get('/api/admin/incidents/$id'),
      api.get('/api/admin/incidents/$id/history?page=1&pageSize=50'),
    ]);
    if (v[1] is! List) {
      throw const ApiException(502, 'Invalid incident history.');
    }
    return (
      IncidentDetails.fromJson(v[0]),
      List<IncidentHistoryEntry>.unmodifiable(
        (v[1] as List).map(IncidentHistoryEntry.fromJson),
      ),
    );
  }

  Future<IncidentDetails> createIncident({
    required String category,
    required IncidentPriority priority,
    String? correlationId,
  }) async {
    final c = category.trim();
    if (c.isEmpty || c.length > 80 || _secret(c) || _secret(correlationId)) {
      throw ArgumentError('Invalid incident metadata.');
    }
    return IncidentDetails.fromJson(
      await api.post('/api/admin/incidents', {
        'category': c,
        'priority': priorityWire(priority),
        'correlationId':
            correlationId?.trim().isEmpty ?? true
                ? null
                : correlationId!.trim(),
      }),
    );
  }

  Future<IncidentDetails> changeStatus(
    IncidentDetails item,
    IncidentStatus status, {
    String? resolutionNotes,
  }) async {
    final notes = resolutionNotes?.trim();
    if (status == IncidentStatus.resolved && (notes == null || notes.isEmpty) ||
        notes != null && (notes.length > 1000 || _secret(notes))) {
      throw ArgumentError('Valid resolution notes are required.');
    }
    return IncidentDetails.fromJson(
      await api.put('/api/admin/incidents/${item.id}/status', {
        'status': statusWire(status),
        'resolutionNotes': notes,
        'expectedConcurrencyToken': item.concurrencyToken,
      }),
    );
  }

  Future<IncidentDetails> assign(IncidentDetails item, String? adminId) async {
    if (adminId != null && !_uuid.hasMatch(adminId)) {
      throw ArgumentError('Invalid administrator ID.');
    }
    return IncidentDetails.fromJson(
      await api.put('/api/admin/incidents/${item.id}/assignment', {
        'assignedAdminId': adminId,
        'expectedConcurrencyToken': item.concurrencyToken,
      }),
    );
  }

  void _page(int p, int s) {
    if (p < 1 || p > 1000000 || s < 1 || s > 100) {
      throw ArgumentError('Invalid pagination.');
    }
  }

  void _reason(String r) {
    final v = r.trim();
    if (v.length < 3 || v.length > 500) {
      throw ArgumentError('A reason of 3 to 500 characters is required.');
    }
  }

  void _id(String id) {
    if (!_uuid.hasMatch(id)) throw ArgumentError('Invalid incident ID.');
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
bool _secret(String? v) =>
    v != null &&
    [
      'password=',
      'secret=',
      'api_key',
      'apikey',
      'bearer ',
      'service_role',
      'private key',
    ].any((m) => v.toLowerCase().contains(m));
