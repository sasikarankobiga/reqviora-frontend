import '../../../../core/network/api_client.dart';

/// The reviewed backend requires a fresh authenticator code per admin read.
class AdminRepository {
  const AdminRepository(this.api);
  final ApiClient api;

  Future<dynamic> read(
    AdminSection section,
    String code, {
    int page = 1,
    String search = '',
    int? statusCode,
  }) async {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      throw const FormatException('Enter a six-digit authenticator code.');
    }
    if (page < 1 ||
        page > 100000 ||
        search.length > 120 ||
        (statusCode != null && (statusCode < 100 || statusCode > 599))) {
      throw const FormatException('Invalid search, page or status.');
    }
    final query = <String, String>{
      if (section.paged) 'page': '$page',
      if (section.paged) 'pageSize': '20',
      if (section.searchable && search.trim().isNotEmpty)
        'search': search.trim(),
      if (section == AdminSection.audit && statusCode != null)
        'statusCode': '$statusCode',
    };
    final result = await api.post(
      Uri(
        path: section.path,
        queryParameters: query.isEmpty ? null : query,
      ).toString(),
      {'code': code},
    );
    final valid =
        section.paged
            ? result is Map &&
                result['items'] is List &&
                (result['items'] as List).every((item) => item is Map) &&
                result['total'] is num &&
                (result['total'] as num).isFinite &&
                (result['total'] as num) >= 0 &&
                (result['total'] as num).toInt() == result['total']
            : section == AdminSection.roles
            ? result is List && result.every((item) => item is Map)
            : result is Map &&
                section.fields.every(result.containsKey) &&
                section.fields.every(
                  (field) =>
                      result[field] is String ||
                      result[field] is num ||
                      result[field] is bool,
                );
    if (!valid) {
      throw const FormatException('Unexpected admin response.');
    }
    return result;
  }
}

enum AdminSection {
  overview('Overview', '/api/admin/overview', false, false),
  users('User directory', '/api/admin/users/search', true, true),
  roles('Roles', '/api/admin/roles/list', false, false),
  projects('Project oversight', '/api/admin/projects/search', true, true),
  audit('Audit events', '/api/admin/audit/search', true, false),
  security('Login security', '/api/admin/security/login-summary', false, false),
  report('System report', '/api/admin/system/report', false, false),
  health('System health', '/api/admin/system/health', false, false);

  const AdminSection(this.label, this.path, this.paged, this.searchable);
  final String label;
  final String path;
  final bool paged;
  final bool searchable;

  // Only explicitly allowed metadata may be rendered.
  List<String> get fields => switch (this) {
    AdminSection.overview => ['users', 'projects', 'drafts', 'auditEvents'],
    AdminSection.users => [
      'id',
      'displayName',
      'email',
      'emailVerified',
      'mfaEnabled',
      'roleId',
    ],
    AdminSection.roles => ['id', 'name'],
    AdminSection.projects => [
      'id',
      'name',
      'industry',
      'primaryPlatform',
      'ownerId',
      'workspaceId',
      'createdAt',
    ],
    AdminSection.audit => [
      'id',
      'userId',
      'method',
      'path',
      'statusCode',
      'occurredAt',
    ],
    AdminSection.security => [
      'totalAttempts',
      'failedAttempts',
      'successfulAttempts',
      'otpRequiredAttempts',
    ],
    AdminSection.report => [
      'totalUsers',
      'totalProjects',
      'totalDrafts',
      'totalRoles',
      'totalAuditEvents',
      'totalFailedLogins',
      'generatedAtUtc',
    ],
    AdminSection.health => ['status', 'totalDurationMs'],
  };
}
