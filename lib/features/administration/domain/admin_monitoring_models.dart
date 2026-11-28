import '../../../core/network/api_client.dart';

int _integer(Map<Object?, Object?> json, String key, {int minimum = 0}) {
  final value = json[key];
  if (value is! int || value < minimum) {
    throw const ApiException(502, 'Invalid administration response.');
  }
  return value;
}

double _number(Map<Object?, Object?> json, String key, {double minimum = 0}) {
  final value = json[key];
  if (value is! num || !value.isFinite || value < minimum) {
    throw const ApiException(502, 'Invalid administration response.');
  }
  return value.toDouble();
}

String _text(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 120) {
    throw const ApiException(502, 'Invalid administration response.');
  }
  return value;
}

DateTime? _optionalDate(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw const ApiException(502, 'Invalid administration response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const ApiException(502, 'Invalid administration response.');
  }
  return parsed.toUtc();
}

class ValidationErrorCounts {
  const ValidationErrorCounts({
    required this.schema,
    required this.brokenReferences,
    required this.unsupportedComponents,
    required this.navigation,
    required this.other,
  });

  final int schema;
  final int brokenReferences;
  final int unsupportedComponents;
  final int navigation;
  final int other;

  int get total =>
      schema + brokenReferences + unsupportedComponents + navigation + other;

  factory ValidationErrorCounts.fromJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const ApiException(502, 'Invalid validation error statistics.');
    }
    return ValidationErrorCounts(
      schema: _integer(value, 'schema'),
      brokenReferences: _integer(value, 'brokenReferences'),
      unsupportedComponents: _integer(value, 'unsupportedComponents'),
      navigation: _integer(value, 'navigation'),
      other: _integer(value, 'other'),
    );
  }
}

class ValidationStatistics {
  const ValidationStatistics({
    required this.attempts,
    required this.succeeded,
    required this.failed,
    required this.successRate,
    required this.failureRate,
    required this.averageDurationMilliseconds,
    required this.errors,
  });

  final int attempts;
  final int succeeded;
  final int failed;
  final double successRate;
  final double failureRate;
  final double averageDurationMilliseconds;
  final ValidationErrorCounts errors;

  factory ValidationStatistics.fromJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const ApiException(502, 'Invalid validation statistics.');
    }
    final result = ValidationStatistics(
      attempts: _integer(value, 'attempts'),
      succeeded: _integer(value, 'succeeded'),
      failed: _integer(value, 'failed'),
      successRate: _number(value, 'successRate'),
      failureRate: _number(value, 'failureRate'),
      averageDurationMilliseconds: _number(
        value,
        'averageDurationMilliseconds',
      ),
      errors: ValidationErrorCounts.fromJson(value['errors']),
    );
    if (result.succeeded + result.failed != result.attempts ||
        result.successRate > 100 ||
        result.failureRate > 100) {
      throw const ApiException(502, 'Inconsistent validation statistics.');
    }
    return result;
  }
}

class ValidationDay {
  const ValidationDay({required this.date, required this.statistics});

  final DateTime date;
  final ValidationStatistics statistics;

  factory ValidationDay.fromJson(Object? value) {
    if (value is! Map<Object?, Object?> || value['date'] is! String) {
      throw const ApiException(502, 'Invalid validation trend.');
    }
    final date = DateTime.tryParse(value['date'] as String);
    if (date == null) {
      throw const ApiException(502, 'Invalid validation trend date.');
    }
    return ValidationDay(
      date: DateTime.utc(date.year, date.month, date.day),
      statistics: ValidationStatistics.fromJson(value['statistics']),
    );
  }
}

class ValidationHealthSnapshot {
  const ValidationHealthSnapshot({required this.summary, required this.trends});

  final ValidationStatistics summary;
  final List<ValidationDay> trends;
}

enum AdminAiJobStatus { pending, processing, completed, failed, cancelled }

AdminAiJobStatus _jobStatus(Object? value) => switch (value) {
  'pending' => AdminAiJobStatus.pending,
  'processing' => AdminAiJobStatus.processing,
  'completed' => AdminAiJobStatus.completed,
  'failed' => AdminAiJobStatus.failed,
  'cancelled' => AdminAiJobStatus.cancelled,
  _ => throw const ApiException(502, 'Unsupported AI queue status.'),
};

class AdminAiJob {
  const AdminAiJob({
    required this.id,
    required this.projectId,
    required this.type,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    required this.createdAt,
    required this.startedAt,
    required this.completedAt,
    required this.durationMilliseconds,
    required this.failureCategory,
    required this.expiredLease,
    required this.stale,
  });

  final String id;
  final String projectId;
  final String type;
  final AdminAiJobStatus status;
  final int attempts;
  final int maxAttempts;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationMilliseconds;
  final String? failureCategory;
  final bool expiredLease;
  final bool stale;

  bool get timedOut => failureCategory == 'timeout';

  factory AdminAiJob.fromJson(Object? value) {
    if (value is! Map<Object?, Object?> ||
        value['durationMilliseconds'] is! int? ||
        value['failureCategory'] is! String? ||
        value['expiredLease'] is! bool ||
        value['stale'] is! bool) {
      throw const ApiException(502, 'Invalid AI job response.');
    }
    final id = _text(value, 'id');
    final projectId = _text(value, 'projectId');
    final createdAt = _optionalDate(value, 'createdAt');
    final duration = value['durationMilliseconds'] as int?;
    final failure = value['failureCategory'] as String?;
    const safeFailures = {'provider', 'timeout', 'expired_lease', 'other'};
    if (!_uuid.hasMatch(id) ||
        !_uuid.hasMatch(projectId) ||
        createdAt == null ||
        duration != null && duration < 0 ||
        failure != null && !safeFailures.contains(failure)) {
      throw const ApiException(502, 'Invalid AI job response.');
    }
    final attempts = _integer(value, 'attempts');
    final maxAttempts = _integer(value, 'maxAttempts', minimum: 1);
    if (attempts > maxAttempts) {
      throw const ApiException(502, 'Invalid AI job attempt count.');
    }
    return AdminAiJob(
      id: id,
      projectId: projectId,
      type: _text(value, 'type'),
      status: _jobStatus(value['status']),
      attempts: attempts,
      maxAttempts: maxAttempts,
      createdAt: createdAt,
      startedAt: _optionalDate(value, 'startedAt'),
      completedAt: _optionalDate(value, 'completedAt'),
      durationMilliseconds: duration,
      failureCategory: failure,
      expiredLease: value['expiredLease'] as bool,
      stale: value['stale'] as bool,
    );
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

class AdminAiJobPage {
  const AdminAiJobPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int total;
  final List<AdminAiJob> items;

  factory AdminAiJobPage.fromJson(Object? value) {
    if (value is! Map<Object?, Object?> || value['items'] is! List) {
      throw const ApiException(502, 'Invalid AI job page.');
    }
    final page = _integer(value, 'page', minimum: 1);
    final pageSize = _integer(value, 'pageSize', minimum: 1);
    final total = _integer(value, 'total');
    final items = (value['items'] as List).map(AdminAiJob.fromJson).toList();
    if (pageSize > 100 || items.length > pageSize || items.length > total) {
      throw const ApiException(502, 'Invalid AI job pagination.');
    }
    return AdminAiJobPage(
      page: page,
      pageSize: pageSize,
      total: total,
      items: List.unmodifiable(items),
    );
  }
}

class AiQueueStatistics {
  const AiQueueStatistics({
    required this.pending,
    required this.processing,
    required this.completed,
    required this.failed,
    required this.cancelled,
    required this.retryAttempts,
    required this.retriedJobs,
    required this.expiredLeases,
    required this.staleJobs,
    required this.oldestPendingSeconds,
    required this.averagePendingAgeSeconds,
    required this.averageProcessingMilliseconds,
    required this.providerFailures,
    required this.timeouts,
  });

  final int pending;
  final int processing;
  final int completed;
  final int failed;
  final int cancelled;
  final int retryAttempts;
  final int retriedJobs;
  final int expiredLeases;
  final int staleJobs;
  final double? oldestPendingSeconds;
  final double? averagePendingAgeSeconds;
  final double? averageProcessingMilliseconds;
  final int providerFailures;
  final int timeouts;

  factory AiQueueStatistics.fromJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const ApiException(502, 'Invalid AI queue statistics.');
    }
    double? optional(String key) {
      final item = value[key];
      if (item == null) return null;
      if (item is! num || !item.isFinite || item < 0) {
        throw const ApiException(502, 'Invalid AI queue statistics.');
      }
      return item.toDouble();
    }

    return AiQueueStatistics(
      pending: _integer(value, 'pending'),
      processing: _integer(value, 'processing'),
      completed: _integer(value, 'completed'),
      failed: _integer(value, 'failed'),
      cancelled: _integer(value, 'cancelled'),
      retryAttempts: _integer(value, 'retryAttempts'),
      retriedJobs: _integer(value, 'retriedJobs'),
      expiredLeases: _integer(value, 'expiredLeases'),
      staleJobs: _integer(value, 'staleJobs'),
      oldestPendingSeconds: optional('oldestPendingSeconds'),
      averagePendingAgeSeconds: optional('averagePendingAgeSeconds'),
      averageProcessingMilliseconds: optional('averageProcessingMilliseconds'),
      providerFailures: _integer(value, 'providerFailures'),
      timeouts: _integer(value, 'timeouts'),
    );
  }
}

class AiQueueHealth {
  const AiQueueHealth({
    required this.providerStatus,
    required this.localWorkerStatus,
    required this.lastLocalPoll,
    required this.queueStatus,
    required this.staleJobs,
  });

  final String providerStatus;
  final String localWorkerStatus;
  final DateTime? lastLocalPoll;
  final String queueStatus;
  final int staleJobs;

  factory AiQueueHealth.fromJson(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const ApiException(502, 'Invalid AI queue health.');
    }
    const statuses = {
      'disabled',
      'unavailable',
      'unknown',
      'degraded',
      'healthy',
    };
    final provider = _text(value, 'providerStatus');
    final worker = _text(value, 'localWorkerStatus');
    final queue = _text(value, 'queueStatus');
    if (!statuses.contains(provider) ||
        !statuses.contains(worker) ||
        !statuses.contains(queue)) {
      throw const ApiException(502, 'Invalid AI queue health status.');
    }
    return AiQueueHealth(
      providerStatus: provider,
      localWorkerStatus: worker,
      lastLocalPoll: _optionalDate(value, 'lastLocalPoll'),
      queueStatus: queue,
      staleJobs: _integer(value, 'staleJobs'),
    );
  }
}

class AiQueueSnapshot {
  const AiQueueSnapshot({
    required this.jobs,
    required this.statistics,
    required this.health,
  });

  final AdminAiJobPage jobs;
  final AiQueueStatistics statistics;
  final AiQueueHealth health;
}
