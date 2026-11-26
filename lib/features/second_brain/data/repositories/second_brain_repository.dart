import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../workspace/data/approval_export_repository.dart';
import '../../domain/second_brain_package.dart';

class SecondBrainRepository {
  const SecondBrainRepository(this.api);

  final ApiClient api;

  int _session() {
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Sign in to view Second Brain.');
    }

    return authSession.generation;
  }

  void _checkSession(int generation) {
    if (!authSession.authenticated || generation != authSession.generation) {
      throw const ApiException(401, 'The account session changed.');
    }
  }

  Future<List<Map<String, dynamic>>> listExports(String projectId) async {
    final generation = _session();

    final result = await ApprovalExportRepository(api).getExports(projectId);

    _checkSession(generation);

    return result;
  }

  Future<SecondBrainPackage> openPackage({
    required String projectId,
    required String exportId,
    required String revisionId,
  }) async {
    final generation = _session();

    if (!SecondBrainPackage.validGuid(projectId) ||
        !SecondBrainPackage.validGuid(exportId) ||
        !SecondBrainPackage.validGuid(revisionId)) {
      throw ArgumentError('Invalid Second Brain identifier.');
    }

    final exports = ApprovalExportRepository(api);

    final metadata = await exports.getExport(projectId, exportId);

    _checkSession(generation);

    final size = metadata['archiveBytes'];
    final hash = metadata['archiveSha256'];

    if (!SecondBrainPackage.sameId(metadata['exportId'], exportId) ||
        !SecondBrainPackage.sameId(
          metadata['approvedRevisionId'],
          revisionId,
        ) ||
        metadata['generatorVersion'] != '1.0.0' ||
        size is! int ||
        size < 4 ||
        size > SecondBrainPackage.maxArchiveBytes ||
        hash is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid export metadata.');
    }

    final bytes = await exports.downloadExport(projectId, exportId);

    _checkSession(generation);

    final result = SecondBrainPackage.read(
      bytes: bytes,
      projectId: projectId,
      revisionId: revisionId,
      expectedSha256: hash,
      expectedSize: size,
    );

    _checkSession(generation);

    return result;
  }
}
