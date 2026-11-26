import '../../../../core/network/api_client.dart';

enum AdminSection {
  overview(
    'Overview',
    '/api/admin/overview',
    [
      'users',
      'projects',
      'drafts',
      'auditEvents',
    ],
  ),

  users(
    'Users',
    '/api/admin/users/search',
    [
      'id',
      'displayName',
      'email',
      'emailVerified',
      'mfaEnabled',
      'roleId',
    ],
    paged: true,
    searchable: true,
  ),

  roles(
    'Roles',
    '/api/admin/roles/list',
    [
      'id',
      'name',
    ],
  ),

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

  audit(
    'Audit',
    '/api/admin/audit/search',
    [
      'id',
      'userId',
      'method',
      'path',
      'statusCode',
      'occurredAt',
    ],
    paged: true,
  ),

  login(
    'Login security',
    '/api/admin/security/login-summary',
    [
      'totalAttempts',
      'failedAttempts',
      'successfulAttempts',
      'otpRequiredAttempts',
    ],
  ),

  report(
    'System report',
    '/api/admin/system/report',
    [
      'totalUsers',
      'totalProjects',
      'totalDrafts',
      'totalRoles',
      'totalAuditEvents',
      'totalFailedLogins',
      'generatedAtUtc',
    ],
  ),

  health(
    'System health',
    '/api/admin/system/health',
    [
      'name',
      'status',
      'totalDurationMs',
    ],
  );

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

  // Compatibility with the develop branch.
  // Both names refer to the same admin section.
  static const AdminSection security = AdminSection.login;
}

class AdminResult {
  const AdminResult(
    this.rows, {
    this.total,
    this.healthStatus,
  });

  final List<Map<String, Object?>> rows;
  final int? total;
  final String? healthStatus;
}

/// The backend requires a fresh authenticator code
/// for each authorized admin read.
class AdminRepository {
  const AdminRepository(this.api);

  final ApiClient api;

  static const int _pageSize = 20;

  static const List<String> _healthCheckFields = [
    'name',
    'status',
  ];

  bool _validCode(String code) {
    return RegExp(r'^[0-9]{6}$').hasMatch(code);
  }

  bool _validParameters({
    required int page,
    required String search,
    int? statusCode,
  }) {
    return page >= 1 &&
        page <= 100000 &&
        search.length <= 120 &&
        (statusCode == null ||
            (statusCode >= 100 && statusCode <= 599));
  }

  Future<dynamic> _request(
    AdminSection section,
    String code, {
    required int page,
    required String search,
    int? statusCode,
  }) async {
    final query = <String, String>{
      if (section.paged) 'page': '$page',
      if (section.paged) 'pageSize': '$_pageSize',

      if (section.searchable && search.trim().isNotEmpty)
        'search': search.trim(),

      if (section == AdminSection.audit && statusCode != null)
        'statusCode': '$statusCode',
    };

    final path = Uri(
      path: section.path,
      queryParameters: query.isEmpty ? null : query,
    ).toString();

    return api.post(
      path,
      {
        'code': code,
      },
    );
  }

  /// Typed admin response used by the feature branch.
  /// Only explicitly permitted metadata is returned.
  Future<AdminResult> load(
    AdminSection section,
    String code, {
    int page = 1,
    String search = '',
    int? statusCode,
  }) async {
    if (!_validCode(code) ||
        !_validParameters(
          page: page,
          search: search,
          statusCode: statusCode,
        )) {
      throw ArgumentError('Invalid admin request');
    }

    final raw = await _request(
      section,
      code,
      page: page,
      search: search,
      statusCode: statusCode,
    );

    if (section.paged) {
      if (raw is! Map ||
          raw['total'] is! int ||
          (raw['total'] as int) < 0 ||
          raw['page'] != page ||
          raw['pageSize'] != _pageSize) {
        throw const FormatException(
          'Invalid admin pagination',
        );
      }

      return AdminResult(
        _rows(
          raw['items'],
          section.fields,
        ),
        total: raw['total'] as int,
      );
    }

    if (section == AdminSection.roles) {
      return AdminResult(
        _rows(
          raw,
          section.fields,
        ),
      );
    }

    if (section == AdminSection.health) {
      if (raw is! Map || raw['status'] is! String) {
        throw const FormatException(
          'Invalid health report',
        );
      }

      return AdminResult(
        _rows(
          raw['checks'],
          _healthCheckFields,
        ),
        healthStatus: raw['status'] as String,
      );
    }

    return AdminResult(
      [
        _row(
          raw,
          section.fields,
        ),
      ],
    );
  }

  /// Compatible with the develop branch admin page.
  Future<dynamic> read(
    AdminSection section,
    String code, {
    int page = 1,
    String search = '',
    int? statusCode,
  }) async {
    if (!_validCode(code)) {
      throw const FormatException(
        'Enter a six-digit authenticator code.',
      );
    }

    if (!_validParameters(
      page: page,
      search: search,
      statusCode: statusCode,
    )) {
      throw const FormatException(
        'Invalid search, page or status.',
      );
    }

    final result = await _request(
      section,
      code,
      page: page,
      search: search,
      statusCode: statusCode,
    );

    if (section.paged) {
      if (result is! Map ||
          result['items'] is! List ||
          !(result['items'] as List).every(
            (item) => item is Map,
          ) ||
          result['total'] is! num ||
          !(result['total'] as num).isFinite ||
          (result['total'] as num) < 0 ||
          (result['total'] as num).toInt() != result['total']) {
        throw const FormatException(
          'Unexpected admin response.',
        );
      }

      return Map<String, dynamic>.unmodifiable({
        'items': _rows(
          result['items'],
          section.fields,
        ),
        'total': result['total'],
        if (result.containsKey('page'))
          'page': _scalar(result['page']),
        if (result.containsKey('pageSize'))
          'pageSize': _scalar(result['pageSize']),
      });
    }

    if (section == AdminSection.roles) {
      return _rows(
        result,
        section.fields,
      );
    }

    if (section == AdminSection.health) {
      if (result is! Map || result['status'] is! String) {
        throw const FormatException(
          'Unexpected admin health response.',
        );
      }

      final duration = result['totalDurationMs'];
      final checks = result['checks'];

      final validDuration =
          duration is num &&
          duration.isFinite &&
          duration >= 0;

      final validChecks =
          checks is List &&
          checks.every((item) => item is Map);

      if ((duration != null && !validDuration) ||
          (checks != null && !validChecks) ||
          (!validDuration && !validChecks)) {
        throw const FormatException(
          'Unexpected admin health response.',
        );
      }

      return Map<String, dynamic>.unmodifiable({
        'status': result['status'],

        if (validDuration)
          'totalDurationMs': duration,

        if (validChecks)
          'checks': _rows(
            checks,
            _healthCheckFields,
          ),
      });
    }

    if (result is! Map ||
        !section.fields.every(result.containsKey) ||
        !section.fields.every(
          (field) =>
              result[field] is String ||
              result[field] is num ||
              result[field] is bool,
        )) {
      throw const FormatException(
        'Unexpected admin response.',
      );
    }

    return _row(
      result,
      section.fields,
    );
  }

  static Map<String, Object?> _row(
    dynamic value,
    List<String> fields,
  ) {
    if (value is! Map) {
      throw const FormatException(
        'Invalid admin row',
      );
    }

    return Map<String, Object?>.unmodifiable({
      for (final field in fields)
        field: _scalar(value[field]),
    });
  }

  static List<Map<String, Object?>> _rows(
    dynamic value,
    List<String> fields,
  ) {
    if (value is! List) {
      throw const FormatException(
        'Invalid admin list',
      );
    }

    return List<Map<String, Object?>>.unmodifiable(
      value.map(
        (item) => _row(item, fields),
      ),
    );
  }

  static Object? _scalar(dynamic value) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool) {
      return value;
    }

    throw const FormatException(
      'Invalid admin field',
    );
  }
}
