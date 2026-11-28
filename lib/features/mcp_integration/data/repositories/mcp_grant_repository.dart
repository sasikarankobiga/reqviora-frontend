import '../../../../core/network/api_client.dart';
import '../../domain/mcp_access_grant.dart';

class McpGrantPage {
  const McpGrantPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int total;
  final List<McpAccessGrant> items;
}

class McpGrantCreated {
  const McpGrantCreated({required this.grant, required this.credential});

  final McpAccessGrant grant;
  final McpGrantCredential credential;
}

class McpGrantRepository {
  const McpGrantRepository(this.api);

  final ApiClient api;

  Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid MCP grant response');
    }
    return Map<String, dynamic>.from(value);
  }

  String _base(String projectId) {
    McpGrantValidation.requireId(projectId, 'project ID');
    return '/api/projects/$projectId/mcp/grants';
  }

  Future<List<McpApprovedRevision>> approvedRevisions(String projectId) async {
    McpGrantValidation.requireId(projectId, 'project ID');
    final value = await api.get('/api/projects/$projectId/approvals');
    if (value is! List) {
      throw const FormatException('Invalid approved revision list');
    }
    final revisions = value
        .map((item) {
          final revision = McpApprovedRevision.fromJson(_object(item));
          if (!McpGrantValidation.sameId(revision.projectId, projectId)) {
            throw const FormatException('Revision belongs to another project');
          }
          return revision;
        })
        .toList(growable: false);
    if (revisions.map((item) => item.revisionId.toLowerCase()).toSet().length !=
        revisions.length) {
      throw const FormatException('Duplicate approved revision');
    }
    return List.unmodifiable(revisions);
  }

  Future<McpGrantPage> list(
    String projectId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid MCP grant page');
    }
    final raw = _object(
      await api.get('${_base(projectId)}?page=$page&pageSize=$pageSize'),
    );
    final rawItems = raw['items'];
    if (raw['page'] != page ||
        raw['pageSize'] != pageSize ||
        raw['total'] is! int ||
        (raw['total'] as int) < 0 ||
        rawItems is! List) {
      throw const FormatException('Invalid MCP grant page');
    }
    final items = rawItems
        .map((item) {
          final grant = McpAccessGrant.fromJson(_object(item));
          if (!grant.belongsTo(projectId)) {
            throw const FormatException('Grant belongs to another project');
          }
          return grant;
        })
        .toList(growable: false);
    if (items.length > raw['total'] ||
        items.map((item) => item.id.toLowerCase()).toSet().length !=
            items.length) {
      throw const FormatException('Invalid MCP grant collection');
    }
    return McpGrantPage(
      page: page,
      pageSize: pageSize,
      total: raw['total'] as int,
      items: List.unmodifiable(items),
    );
  }

  Future<McpGrantCreated> create({
    required String projectId,
    required String approvedRevisionId,
    required Duration lifetime,
  }) async {
    McpGrantValidation.requireId(approvedRevisionId, 'revision ID');
    final minutes = lifetime.inMinutes;
    if (minutes < 5 ||
        minutes > 43200 ||
        lifetime != Duration(minutes: minutes)) {
      throw ArgumentError('Invalid MCP grant lifetime');
    }
    final raw = _object(
      await api.post(_base(projectId), {
        'approvedRevisionId': approvedRevisionId,
        'lifetimeMinutes': minutes,
      }),
    );
    final grant = McpAccessGrant.fromJson(_object(raw['grant']));
    final credential = raw['credential'];
    if (!grant.belongsTo(projectId) ||
        !McpGrantValidation.sameId(grant.revisionId, approvedRevisionId) ||
        credential is! String) {
      throw const FormatException('Invalid created MCP grant');
    }
    return McpGrantCreated(
      grant: grant,
      credential: McpGrantCredential(credential),
    );
  }

  Future<McpAccessGrant> revoke({
    required String projectId,
    required String grantId,
    required String reason,
  }) async {
    McpGrantValidation.requireId(grantId, 'grant ID');
    final cleanReason = reason.trim();
    if (cleanReason.length < 3 || cleanReason.length > 500) {
      throw ArgumentError('Invalid revocation reason');
    }
    final grant = McpAccessGrant.fromJson(
      _object(
        await api.post('${_base(projectId)}/$grantId/revoke', {
          'reason': cleanReason,
        }),
      ),
    );
    if (!grant.belongsTo(projectId) ||
        !McpGrantValidation.sameId(grant.id, grantId) ||
        grant.revokedAt == null) {
      throw const FormatException('Invalid revoked MCP grant');
    }
    return grant;
  }
}
