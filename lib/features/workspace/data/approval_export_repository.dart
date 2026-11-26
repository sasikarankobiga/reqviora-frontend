import '../../../core/network/api_client.dart';

class ApprovalExportRepository {
  const ApprovalExportRepository(this.api);

  final ApiClient api;

  String _project(String projectId) => '/api/projects/$projectId';

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Invalid server response');
    }

    return Map<String, dynamic>.from(value);
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) {
      throw const FormatException('Invalid server list response');
    }

    return value.map(_object).toList();
  }

  void _requireGuid(String value, String field) {
    if (!RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value) ||
        value == '00000000-0000-0000-0000-000000000000') {
      throw ArgumentError('Invalid $field');
    }
  }

  Future<Map<String, dynamic>> approve({
    required String projectId,
    required String expectedConcurrencyToken,
    required String validationRunId,
    required bool explicitlyConfirmed,
  }) async {
    _requireGuid(projectId, 'project ID');
    _requireGuid(validationRunId, 'validation run ID');

    if (!explicitlyConfirmed) {
      throw ArgumentError('Explicit approval is required');
    }

    if (expectedConcurrencyToken.trim().isEmpty) {
      throw ArgumentError('Concurrency token is required');
    }

    return _object(
      await api.post('${_project(projectId)}/approvals', {
        'expectedConcurrencyToken': expectedConcurrencyToken,
        'validationRunId': validationRunId,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getRevisions(String projectId) async {
    _requireGuid(projectId, 'project ID');

    return _list(await api.get('${_project(projectId)}/approvals'));
  }

  Future<Map<String, dynamic>> getRevision(
    String projectId,
    String revisionId,
  ) async {
    _requireGuid(projectId, 'project ID');
    _requireGuid(revisionId, 'revision ID');

    return _object(
      await api.get('${_project(projectId)}/approvals/$revisionId'),
    );
  }

  Future<Map<String, dynamic>> createExport(
    String projectId,
    String revisionId,
  ) async {
    _requireGuid(projectId, 'project ID');
    _requireGuid(revisionId, 'revision ID');

    return _object(
      await api.post(
        '${_project(projectId)}/exports/from-revision/$revisionId',
        {},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getExports(String projectId) async {
    _requireGuid(projectId, 'project ID');

    return _list(await api.get('${_project(projectId)}/exports'));
  }

  Future<Map<String, dynamic>> getExport(
    String projectId,
    String exportId,
  ) async {
    _requireGuid(projectId, 'project ID');
    _requireGuid(exportId, 'export ID');

    return _object(await api.get('${_project(projectId)}/exports/$exportId'));
  }

  Future<List<int>> downloadExport(String projectId, String exportId) async {
    _requireGuid(projectId, 'project ID');
    _requireGuid(exportId, 'export ID');

    final bytes = await api.getBytes(
      '${_project(projectId)}/exports/$exportId/download',
    );

    if (bytes.length < 4 ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      throw const FormatException('Invalid ZIP archive response');
    }

    return bytes;
  }
}
