class AdminExportDiagnostic {
  const AdminExportDiagnostic({
    required this.id,
    required this.projectId,
    required this.approvedRevisionId,
    required this.exportType,
    required this.status,
    required this.createdAt,
    required this.startedAt,
    required this.integrityStatus,
    this.exportRecordId,
    this.completedAt,
    this.durationMilliseconds,
    this.failureCode,
    this.failureCategory,
  });

  final String id;
  final String projectId;
  final String approvedRevisionId;
  final String? exportRecordId;
  final String exportType;
  final String status;
  final DateTime createdAt;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMilliseconds;
  final String? failureCode;
  final String? failureCategory;
  final String integrityStatus;

  factory AdminExportDiagnostic.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid export job.');
    final status = value['status'];
    final duration = value['durationMilliseconds'];
    if (status is! String ||
        !const {'Succeeded', 'Failed'}.contains(status) ||
        duration != null && (duration is! int || duration < 0)) {
      throw const FormatException('Invalid export job metadata.');
    }
    return AdminExportDiagnostic(
      id: _id(value['id']),
      projectId: _id(value['projectId']),
      approvedRevisionId: _id(value['approvedRevisionId']),
      exportRecordId: _nullableId(value['exportRecordId']),
      exportType: _text(value['exportType'], 80),
      status: status,
      createdAt: _requiredDate(value['createdAt']),
      startedAt: _requiredDate(value['startedAt']),
      completedAt: _nullableDate(value['completedAt']),
      durationMilliseconds: duration as int?,
      failureCode: _nullableText(value['failureCode'], 100),
      failureCategory: _nullableText(value['failureCategory'], 100),
      integrityStatus: _text(value['integrityStatus'], 40),
    );
  }
}

class AdminExportPage {
  const AdminExportPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });
  final int page;
  final int pageSize;
  final int total;
  final List<AdminExportDiagnostic> items;

  factory AdminExportPage.fromJson(Object? value) {
    if (value is! Map || value['items'] is! List) {
      throw const FormatException('Invalid export job page.');
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
      throw const FormatException('Invalid export pagination.');
    }
    return AdminExportPage(
      page: page,
      pageSize: pageSize,
      total: total,
      items: List.unmodifiable(
        (value['items'] as List).map(AdminExportDiagnostic.fromJson),
      ),
    );
  }
}

class AdminExportSummary {
  const AdminExportSummary({
    required this.total,
    required this.successful,
    required this.failed,
    required this.successRate,
    required this.averageDurationMilliseconds,
    required this.integrityVerified,
    required this.integrityFailed,
  });
  final int total;
  final int successful;
  final int failed;
  final double successRate;
  final double averageDurationMilliseconds;
  final int integrityVerified;
  final int integrityFailed;

  factory AdminExportSummary.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid export summary.');
    int count(String key) {
      final result = value[key];
      if (result is! int || result < 0) {
        throw const FormatException('Invalid export summary.');
      }
      return result;
    }

    double metric(String key) {
      final result = value[key];
      if (result is! num || !result.isFinite || result < 0) {
        throw const FormatException('Invalid export summary.');
      }
      return result.toDouble();
    }

    return AdminExportSummary(
      total: count('total'),
      successful: count('successful'),
      failed: count('failed'),
      successRate: metric('successRate'),
      averageDurationMilliseconds: metric('averageDurationMilliseconds'),
      integrityVerified: count('integrityVerified'),
      integrityFailed: count('integrityFailed'),
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
String _text(Object? value, int maximum) {
  if (value is! String || value.isEmpty || value.length > maximum) {
    throw const FormatException('Invalid text metadata.');
  }
  return value;
}

String? _nullableText(Object? value, int maximum) =>
    value == null ? null : _text(value, maximum);
DateTime _requiredDate(Object? value) {
  final result = value is String ? DateTime.tryParse(value)?.toUtc() : null;
  if (result == null) throw const FormatException('Invalid timestamp.');
  return result;
}

DateTime? _nullableDate(Object? value) =>
    value == null ? null : _requiredDate(value);
