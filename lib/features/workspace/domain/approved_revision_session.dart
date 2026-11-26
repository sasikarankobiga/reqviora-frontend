import '../../../core/auth/auth_session.dart';

/// Remembers approval metadata only for the current in-memory account session.
/// The server remains authoritative and should replace this bridge when a
/// revision-history read endpoint is available.
class ApprovedRevisionSession {
  int _generation = -1;
  final Map<String, String> _revisionByDraft = {};

  void _synchronize() {
    if (!authSession.authenticated) {
      _generation = authSession.generation;
      _revisionByDraft.clear();
      return;
    }
    if (_generation == authSession.generation) return;
    _generation = authSession.generation;
    _revisionByDraft.clear();
  }

  String _key(String projectId, int draftVersion) =>
      '$projectId::$draftVersion';

  String? read(String projectId, int draftVersion) {
    _synchronize();
    if (!authSession.authenticated) return null;
    return _revisionByDraft[_key(projectId, draftVersion)];
  }

  void remember(String projectId, int draftVersion, String revisionId) {
    _synchronize();
    if (!authSession.authenticated || revisionId.isEmpty) return;
    _revisionByDraft[_key(projectId, draftVersion)] = revisionId;
  }
}

final approvedRevisionSession = ApprovedRevisionSession();
