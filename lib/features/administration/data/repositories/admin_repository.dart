import '../../../../core/network/api_client.dart';

enum AdminSection {
  overview('Overview', '/api/admin/overview', [
    'users',
    'projects',
    'drafts',
    'auditEvents',
  ]),
  users(
    'Users',
    '/api/admin/users/search',
    ['id', 'displayName', 'email', 'emailVerified', 'mfaEnabled', 'roleId'],
    paged: true,
    searchable: true,
  ),
  roles('Roles', '/api/admin/roles/list', ['id', 'name']),
  projects(
    'Projects',
    '/api/admin/projects/search',
    [
      'id',
      'name',
      'industry',
      'primaryPlatform',
      'ownerId',
      'workspaceId',
      'createdAt',
    ],
    paged: true,
    searchable: true,
  ),
  audit('Audit', '/api/admin/audit/search', [
    'id',
    'userId',
    'method',
    'path',
    'statusCode',
    'occurredAt',
  ], paged: true),
  login('Login security', '/api/admin/security/login-summary', [
    'totalAttempts',
    'failedAttempts',
    'successfulAttempts',
    'otpRequiredAttempts',
  ]),
  report('System report', '/api/admin/system/report', [
    'totalUsers',
    'totalProjects',
    'totalDrafts',
    'totalRoles',
    'totalAuditEvents',
    'totalFailedLogins',
    'generatedAtUtc',
  ]),
  health('System health', '/api/admin/system/health', ['name', 'status']);

  const AdminSection(
    this.label,
    this.path,
    this.fields, {
    this.paged = false,
    this.searchable = false,
  });

  final String label;
  final String path;
  final List<String> fields;
  final bool paged;
  final bool searchable;
}

class AdminResult {
  const AdminResult(this.rows, {this.total, this.healthStatus});

  final List<Map<String, Object?>> rows;
  final int? total;
  final String? healthStatus;
}

class AdminRepository {
  const AdminRepository(this.api);

  final ApiClient api;

  Future<AdminResult> load(
    AdminSection section,
    String code, {
    int page = 1,
    String search = '',
  }) async {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code) ||
        page < 1 ||
        page > 100000 ||
        search.length > 120) {
      throw ArgumentError('Invalid admin request');
    }

    final query = <String, String>{
      if (section.paged) 'page': '$page',
      if (section.paged) 'pageSize': '20',
      if (section.searchable && search.trim().isNotEmpty)
        'search': search.trim(),
    };

    final path =
        Uri(
          path: section.path,
          queryParameters: query.isEmpty ? null : query,
        ).toString();

    final raw = await api.post(path, {'code': code});

    Map<String, Object?> row(dynamic value) {
      if (value is! Map) {
        throw const FormatException('Invalid admin row');
      }

      return Map.unmodifiable({
        for (final field in section.fields) field: _scalar(value[field]),
      });
    }

    List<Map<String, Object?>> rows(dynamic value) {
      if (value is! List) {
        throw const FormatException('Invalid admin list');
      }

      return List.unmodifiable(value.map(row));
    }

    if (section.paged) {
      if (raw is! Map ||
          raw['total'] is! int ||
          (raw['total'] as int) < 0 ||
          raw['page'] != page ||
          raw['pageSize'] != 20) {
        throw const FormatException('Invalid admin pagination');
      }

      return AdminResult(rows(raw['items']), total: raw['total'] as int);
    }

    if (section == AdminSection.roles) {
      return AdminResult(rows(raw));
    }

    if (section == AdminSection.health) {
      if (raw is! Map || raw['status'] is! String) {
        throw const FormatException('Invalid health report');
      }

      return AdminResult(
        rows(raw['checks']),
        healthStatus: raw['status'] as String,
      );
    }

    return AdminResult([row(raw)]);
  }

  static Object? _scalar(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    throw const FormatException('Invalid admin field');
  }
}
