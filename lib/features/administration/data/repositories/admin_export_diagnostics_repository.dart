import '../../../../core/network/api_client.dart';
import '../../domain/admin_export_diagnostic.dart';

enum AdminExportStatus { all, succeeded, failed }

class AdminExportDiagnosticsRepository {
  const AdminExportDiagnosticsRepository(this.api);

  final ApiClient api;

  Future<AdminExportPage> list({
    int page = 1,
    int pageSize = 20,
    AdminExportStatus status = AdminExportStatus.all,
    String? projectId,
    DateTime? from,
    DateTime? to,
  }) async {
    _validate(page, pageSize, projectId, from, to);
    final path =
        Uri(
          path: '/api/admin/exports/jobs',
          queryParameters: <String, String>{
            'page': '$page',
            'pageSize': '$pageSize',
            if (status != AdminExportStatus.all)
              'status':
                  status == AdminExportStatus.succeeded
                      ? 'Succeeded'
                      : 'Failed',
            if (projectId != null) 'projectId': projectId,
            if (from != null) 'from': from.toUtc().toIso8601String(),
            if (to != null) 'to': to.toUtc().toIso8601String(),
          },
        ).toString();
    return AdminExportPage.fromJson(await api.get(path));
  }

  Future<AdminExportDiagnostic> details(String jobId) async {
    if (!_uuid.hasMatch(jobId)) {
      throw ArgumentError('Invalid export job identifier.');
    }
    return AdminExportDiagnostic.fromJson(
      await api.get('/api/admin/exports/jobs/$jobId'),
    );
  }

  Future<AdminExportSummary> summary({DateTime? from, DateTime? to}) async {
    _validate(1, 1, null, from, to);
    final path =
        Uri(
          path: '/api/admin/exports/summary',
          queryParameters: <String, String>{
            if (from != null) 'from': from.toUtc().toIso8601String(),
            if (to != null) 'to': to.toUtc().toIso8601String(),
          },
        ).toString();
    return AdminExportSummary.fromJson(await api.get(path));
  }

  void _validate(
    int page,
    int pageSize,
    String? projectId,
    DateTime? from,
    DateTime? to,
  ) {
    if (page < 1 ||
        page > 1000000 ||
        pageSize < 1 ||
        pageSize > 100 ||
        projectId != null && !_uuid.hasMatch(projectId) ||
        from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('Invalid export diagnostic filters.');
    }
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
