import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

bool _validGuid(String value) =>
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value) &&
    value != '00000000-0000-0000-0000-000000000000';

class HistoricalDesign {
  const HistoricalDesign({
    required this.id,
    required this.version,
    required this.timestamp,
    required this.approved,
    required this.blueprint,
  });

  final String id;
  final int version;
  final DateTime timestamp;
  final bool approved;
  final Map<String, dynamic>? blueprint;
}

/// Read-only access to historical server snapshots.
/// Does not approve, restore or modify a project.
class RevisionHistoryRepository {
  const RevisionHistoryRepository(this.api);

  final ApiClient api;

  int _session() {
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Sign in to view project history.');
    }

    return authSession.generation;
  }

  void _checkSession(int generation) {
    if (!authSession.authenticated || authSession.generation != generation) {
      throw const ApiException(401, 'The account session changed.');
    }
  }

  String _base(String projectId) {
    if (!_validGuid(projectId)) {
      throw ArgumentError('Invalid project ID.');
    }

    return '/api/projects/$projectId';
  }

  HistoricalDesign _parse(
    dynamic raw,
    String projectId, {
    required bool approved,
  }) {
    if (raw is! Map) {
      throw const FormatException('Invalid historical design.');
    }

    final id = raw[approved ? 'revisionId' : 'draftVersionId'];
    final version = raw[approved ? 'draftVersion' : 'version'];
    final timestamp = raw[approved ? 'approvedAt' : 'savedAt'];

    if (id is! String ||
        !_validGuid(id) ||
        version is! int ||
        version < 1 ||
        timestamp is! String) {
      throw const FormatException('Invalid historical metadata.');
    }

    final date = DateTime.tryParse(timestamp);

    if (date == null) {
      throw const FormatException('Invalid historical timestamp.');
    }

    final value = raw['blueprint'];
    Map<String, dynamic>? blueprint;

    if (value != null) {
      if (value is! Map ||
          value['projectId'] is! String ||
          (value['projectId'] as String).toLowerCase() !=
              projectId.toLowerCase() ||
          value['screens'] is! List ||
          value['components'] is! List) {
        throw const FormatException('Invalid historical Blueprint.');
      }

      blueprint = Map<String, dynamic>.from(value);
    }

    if (approved && blueprint == null) {
      throw const FormatException('Approved Blueprint is missing.');
    }

    return HistoricalDesign(
      id: id,
      version: version,
      timestamp: date,
      approved: approved,
      blueprint: blueprint,
    );
  }

  Future<List<HistoricalDesign>> _load(
    String projectId, {
    required bool approved,
  }) async {
    final generation = _session();
    final base = _base(projectId);

    final path =
        approved ? '$base/blueprints/approved' : '$base/drafts/versions';

    final raw = await api.get(path);

    _checkSession(generation);

    if (raw is! List) {
      throw const FormatException('Invalid history response.');
    }

    final ids = <String>{};
    final result = <HistoricalDesign>[];

    for (final row in raw) {
      final item = _parse(row, projectId, approved: approved);

      if (!ids.add(item.id.toLowerCase())) {
        throw const FormatException('Duplicate historical record.');
      }

      result.add(item);
    }

    result.sort((a, b) => b.version.compareTo(a.version));

    return List.unmodifiable(result);
  }

  Future<List<HistoricalDesign>> approvedHistory(String projectId) =>
      _load(projectId, approved: true);

  Future<List<HistoricalDesign>> draftHistory(String projectId) =>
      _load(projectId, approved: false);

  Future<HistoricalDesign> approvedRevision(
    String projectId,
    String revisionId,
  ) async {
    final generation = _session();
    final base = _base(projectId);

    if (!_validGuid(revisionId)) {
      throw ArgumentError('Invalid revision ID.');
    }

    final raw = await api.get('$base/blueprints/approved/$revisionId');

    _checkSession(generation);

    final result = _parse(raw, projectId, approved: true);

    if (result.id.toLowerCase() != revisionId.toLowerCase()) {
      throw const FormatException('Revision identity mismatch.');
    }

    return result;
  }
}
