import 'dart:convert';

import 'blueprint_recovery_storage_stub.dart'
    if (dart.library.html) 'blueprint_recovery_storage_web.dart'
    as storage;

/// Best-effort recovery for unsaved Blueprint edits.
/// This is not a Backend save or an approved revision.
class BlueprintRecoveryStore {
  const BlueprintRecoveryStore();

  String _key(String projectId) => 'reqviora:blueprint-recovery:v1:$projectId';

  void save(String projectId, int version, Map<String, dynamic> blueprint) {
    try {
      storage.write(
        _key(projectId),
        jsonEncode({'version': version, 'blueprint': blueprint}),
      );
    } catch (_) {
      // Browser storage can be unavailable or full.
      // Backend saves remain independent of local recovery.
    }
  }

  Map<String, dynamic>? restore(String projectId, int version) {
    try {
      final raw = storage.read(_key(projectId));
      if (raw == null) return null;

      final decoded = jsonDecode(raw);

      if (decoded is! Map ||
          decoded['version'] != version ||
          decoded['blueprint'] is! Map) {
        clear(projectId);
        return null;
      }

      return Map<String, dynamic>.from(decoded['blueprint'] as Map);
    } catch (_) {
      clear(projectId);
      return null;
    }
  }

  void clear(String projectId) {
    try {
      storage.remove(_key(projectId));
    } catch (_) {
      // Recovery cleanup is best-effort.
    }
  }
}
