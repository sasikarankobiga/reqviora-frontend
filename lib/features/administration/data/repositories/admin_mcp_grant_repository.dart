import '../../../../core/network/api_client.dart';
import '../../domain/admin_mcp_grant.dart';

class AdminMcpGrantRepository {
  AdminMcpGrantRepository(this.api);

  final ApiClient api;
  final Set<String> _revocationsInFlight = <String>{};

  Future<AdminMcpGrantPage> list({
    int page = 1,
    int pageSize = 20,
    String search = '',
    AdminMcpGrantState state = AdminMcpGrantState.all,
    String? projectId,
  }) async {
    final query = search.trim();
    if (page < 1 ||
        page > 1000000 ||
        pageSize < 1 ||
        pageSize > 100 ||
        query.length > 100 ||
        projectId != null && !_uuid.hasMatch(projectId)) {
      throw ArgumentError('Invalid MCP grant filters.');
    }
    final path =
        Uri(
          path: '/api/admin/mcp/grants',
          queryParameters: <String, String>{
            'page': '$page',
            'pageSize': '$pageSize',
            'state': state.name,
            if (query.isNotEmpty) 'search': query,
            if (projectId != null) 'projectId': projectId,
          },
        ).toString();
    return AdminMcpGrantPage.fromJson(await api.get(path));
  }

  Future<AdminMcpGrant> details(String grantId) async {
    _requireId(grantId);
    return AdminMcpGrant.fromJson(
      await api.get('/api/admin/mcp/grants/$grantId'),
    );
  }

  Future<AdminMcpGrant> revoke(String grantId, String reason) async {
    _requireId(grantId);
    final normalized = reason.trim();
    if (normalized.length < 3 || normalized.length > 500) {
      throw ArgumentError(
        'A 3 to 500 character revocation reason is required.',
      );
    }
    if (!_revocationsInFlight.add(grantId)) {
      throw StateError('A revocation request is already in progress.');
    }
    try {
      return AdminMcpGrant.fromJson(
        await api.post(
          '/api/admin/mcp/grants/$grantId/revoke',
          <String, dynamic>{'reason': normalized},
        ),
      );
    } finally {
      _revocationsInFlight.remove(grantId);
    }
  }

  void _requireId(String value) {
    if (!_uuid.hasMatch(value)) {
      throw ArgumentError('Invalid grant identifier.');
    }
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
