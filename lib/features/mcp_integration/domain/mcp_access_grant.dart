/// Frontend domain models only.
///
/// These are not backend transport DTOs.
/// Map the final verified API contract into these models
/// before enabling grant lifecycle operations.

library;

enum McpGrantStatus { active, expired, revoked }

class McpGrantValidation {
  const McpGrantValidation._();

  static bool validId(String value) =>
      RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(value) &&
      value != '00000000-0000-0000-0000-000000000000';

  static void requireId(String value, String field) {
    if (!validId(value)) {
      throw ArgumentError('Invalid $field.');
    }
  }

  static bool sameId(String first, String second) =>
      first.toLowerCase() == second.toLowerCase();
}

/// Approved revision selection obtained from trusted
/// project approval metadata.
class McpApprovedRevision {
  McpApprovedRevision({
    required this.projectId,
    required this.revisionId,
    required this.draftVersion,
  }) {
    McpGrantValidation.requireId(projectId, 'project ID');
    McpGrantValidation.requireId(revisionId, 'revision ID');

    if (draftVersion < 1) {
      throw ArgumentError('Invalid approved draft version.');
    }
  }

  final String projectId;
  final String revisionId;
  final int draftVersion;
}

/// Non-sensitive grant metadata.
/// Raw credentials are deliberately excluded.
class McpAccessGrant {
  McpAccessGrant({
    required this.id,
    required this.projectId,
    required this.revisionId,
    required DateTime createdAt,
    required DateTime expiresAt,
    DateTime? revokedAt,
  }) : createdAt = createdAt.toUtc(),
       expiresAt = expiresAt.toUtc(),
       revokedAt = revokedAt?.toUtc() {
    McpGrantValidation.requireId(id, 'grant ID');
    McpGrantValidation.requireId(projectId, 'project ID');
    McpGrantValidation.requireId(revisionId, 'revision ID');

    if (!this.expiresAt.isAfter(this.createdAt)) {
      throw ArgumentError('Expiry must follow creation.');
    }

    final revoked = this.revokedAt;

    if (revoked != null && revoked.isBefore(this.createdAt)) {
      throw ArgumentError('Invalid revocation timestamp.');
    }
  }

  final String id;
  final String projectId;
  final String revisionId;

  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  McpGrantStatus statusAt(DateTime now) {
    if (revokedAt != null) {
      return McpGrantStatus.revoked;
    }

    if (!now.toUtc().isBefore(expiresAt)) {
      return McpGrantStatus.expired;
    }

    return McpGrantStatus.active;
  }

  bool belongsTo(String expectedProjectId) =>
      McpGrantValidation.sameId(projectId, expectedProjectId);

  bool matchesRevision(McpApprovedRevision revision) =>
      belongsTo(revision.projectId) &&
      McpGrantValidation.sameId(revisionId, revision.revisionId);

  bool canRequestRevocationAt(DateTime now) =>
      statusAt(now) == McpGrantStatus.active;
}

/// Internal UI intent, not a backend request DTO.
class McpGrantCreationIntent {
  McpGrantCreationIntent({
    required this.projectId,
    required this.revision,
    required DateTime expiresAt,
    required DateTime now,
    required bool confirmed,
  }) : expiresAt = expiresAt.toUtc() {
    McpGrantValidation.requireId(projectId, 'project ID');

    if (!confirmed) {
      throw ArgumentError('Explicit confirmation required.');
    }

    if (!McpGrantValidation.sameId(projectId, revision.projectId)) {
      throw ArgumentError('Revision belongs to another project.');
    }

    if (!this.expiresAt.isAfter(now.toUtc())) {
      throw ArgumentError('Grant expiry must be in the future.');
    }
  }

  final String projectId;
  final McpApprovedRevision revision;
  final DateTime expiresAt;
}

/// One-time credential container.
///
/// Never persist this object, include it in grant lists,
/// or send it to analytics or application logs.
class McpGrantCredential {
  McpGrantCredential(String value) : _value = value {
    if (value.trim().isEmpty ||
        value.trim() != value ||
        RegExp(r'\s').hasMatch(value)) {
      throw ArgumentError('Invalid grant credential.');
    }
  }

  String? _value;

  bool get available => _value != null;

  String? take() {
    final value = _value;
    _value = null;
    return value;
  }

  void clear() {
    _value = null;
  }

  @override
  String toString() => 'McpGrantCredential([REDACTED])';
}
