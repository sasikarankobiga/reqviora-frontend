import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/admin_monitoring_models.dart';

class AdminMonitoringRepository {
  const AdminMonitoringRepository(this.api);

  final ApiClient api;

  void _authorized() {
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Sign in to access administration.');
    }
  }

  String _dateRange(String path, DateTime? from, DateTime? to) {
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('The date range is invalid.');
    }
    String day(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    return Uri(
      path: path,
      queryParameters: {
        if (from != null) 'from': day(from),
        if (to != null) 'to': day(to),
      },
    ).toString();
  }

  Future<ValidationHealthSnapshot> validationHealth({
    DateTime? from,
    DateTime? to,
  }) async {
    _authorized();
    final generation = authSession.generation;
    final values = await Future.wait([
      api.get(_dateRange('/api/admin/validation/summary', from, to)),
      api.get(_dateRange('/api/admin/validation/trends', from, to)),
    ]);
    if (generation != authSession.generation || !authSession.authenticated) {
      throw const ApiException(401, 'The administration session changed.');
    }
    if (values[1] is! List) {
      throw const ApiException(502, 'Invalid validation trends.');
    }
    return ValidationHealthSnapshot(
      summary: ValidationStatistics.fromJson(values[0]),
      trends: List.unmodifiable(
        (values[1] as List).map(ValidationDay.fromJson),
      ),
    );
  }

  Future<AiQueueSnapshot> aiQueue({
    int page = 1,
    int pageSize = 20,
    AdminAiJobStatus? status,
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    _authorized();
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid AI queue pagination.');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('The date range is invalid.');
    }
    final normalizedType = type?.trim();
    if (normalizedType != null && normalizedType != 'completion') {
      throw ArgumentError('Unsupported AI job type.');
    }
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (status != null) 'status': status.name,
      if (normalizedType?.isNotEmpty ?? false) 'type': normalizedType!,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final statisticsQuery = <String, String>{
      if (normalizedType?.isNotEmpty ?? false) 'type': normalizedType!,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };
    final generation = authSession.generation;
    final values = await Future.wait([
      api.get(
        Uri(path: '/api/admin/ai-jobs', queryParameters: query).toString(),
      ),
      api.get(
        Uri(
          path: '/api/admin/ai-jobs/summary',
          queryParameters: statisticsQuery.isEmpty ? null : statisticsQuery,
        ).toString(),
      ),
      api.get('/api/admin/ai-jobs/health'),
    ]);
    if (generation != authSession.generation || !authSession.authenticated) {
      throw const ApiException(401, 'The administration session changed.');
    }
    return AiQueueSnapshot(
      jobs: AdminAiJobPage.fromJson(values[0]),
      statistics: AiQueueStatistics.fromJson(values[1]),
      health: AiQueueHealth.fromJson(values[2]),
    );
  }

  Future<AdminAiJob> aiJob(String id) async {
    _authorized();
    if (!_uuid.hasMatch(id)) throw ArgumentError('Invalid AI job ID.');
    final generation = authSession.generation;
    final value = await api.get('/api/admin/ai-jobs/$id');
    if (generation != authSession.generation || !authSession.authenticated) {
      throw const ApiException(401, 'The administration session changed.');
    }
    return AdminAiJob.fromJson(value);
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
