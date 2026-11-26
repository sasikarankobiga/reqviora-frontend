import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class DraftRestoreState {
  const DraftRestoreState._({
    required this.projectId,
    required this.version,
    required this.concurrencyToken,
    required this.approved,
    required this.sessionGeneration,
  });

  final String projectId;
  final int version;
  final String concurrencyToken;
  final bool approved;
  final int sessionGeneration;
}

/// Contract reference:
/// reqviora-backend, feature/kobiga-core-workflow, 18d96ad.
///
/// Restore must remain inactive until the integrated backend
/// supports this endpoint.
class DraftRestoreRepository {
  const DraftRestoreRepository(this.api);

  final ApiClient api;

  bool _guid(String value) =>
      RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(value) &&
      value != '00000000-0000-0000-0000-000000000000';

  int _session() {
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Authentication required.');
    }

    return authSession.generation;
  }

  void _checkSession(int generation) {
    if (!authSession.authenticated || generation != authSession.generation) {
      throw const ApiException(401, 'Account session changed.');
    }
  }

  DraftRestoreState _parse(dynamic raw, String projectId, int generation) {
    if (raw is! Map) {
      throw const FormatException('Invalid draft response.');
    }

    final returnedProject = raw['projectId'];
    final version = raw['version'];
    final token = raw['concurrencyToken'];
    final approvedId = raw['approvedRevisionId'];

    if (returnedProject is! String ||
        returnedProject.toLowerCase() != projectId.toLowerCase() ||
        version is! int ||
        version < 1 ||
        version > 2147483647 ||
        token is! String ||
        !_guid(token) ||
        raw['draft'] is! Map ||
        (approvedId != null && (approvedId is! String || !_guid(approvedId)))) {
      throw const FormatException('Invalid draft identity or metadata.');
    }

    return DraftRestoreState._(
      projectId: projectId,
      version: version,
      concurrencyToken: token,
      approved: approvedId != null,
      sessionGeneration: generation,
    );
  }

  Future<DraftRestoreState> current(String projectId) async {
    final generation = _session();

    if (!_guid(projectId)) {
      throw ArgumentError('Invalid project ID.');
    }

    final raw = await api.get('/api/projects/$projectId/drafts/current');

    _checkSession(generation);

    return _parse(raw, projectId, generation);
  }

  Future<DraftRestoreState> restore({
    required DraftRestoreState current,
    required int historicalVersion,
    required bool confirmed,
  }) async {
    final generation = _session();

    _checkSession(current.sessionGeneration);

    if (!confirmed) {
      throw ArgumentError('Explicit restore confirmation required.');
    }

    if (current.approved) {
      throw StateError('Approved drafts cannot be restored.');
    }

    if (historicalVersion < 1 ||
        historicalVersion >= current.version ||
        current.version >= 2147483647) {
      throw ArgumentError('Invalid historical draft version.');
    }

    final raw = await api.post(
      '/api/projects/${current.projectId}/drafts/'
      'versions/$historicalVersion/restore',
      {'expectedConcurrencyToken': current.concurrencyToken},
    );

    _checkSession(generation);

    final result = _parse(raw, current.projectId, generation);

    if (result.approved ||
        result.version != current.version + 1 ||
        result.concurrencyToken.toLowerCase() ==
            current.concurrencyToken.toLowerCase()) {
      throw const FormatException(
        'Unexpected restoration receipt. Reload server state.',
      );
    }

    return result;
  }
}
