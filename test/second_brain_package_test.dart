import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/second_brain/domain/second_brain_package.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const revisionId = '22222222-2222-4222-8222-222222222222';
const otherId = '33333333-3333-4333-8333-333333333333';

List<int> createPackage({
  String manifestProject = projectId,
  String manifestRevision = revisionId,
  String approval = 'approved',
  bool badDocumentHash = false,
  bool unsafeEntry = false,
  bool missingFile = false,
  bool wrongSnapshot = false,
}) {
  final archive = Archive();
  final manifestFiles = <Map<String, dynamic>>[];

  for (final name in SecondBrainPackage.referenceNames) {
    final text =
        name == 'project.json'
            ? jsonEncode({
              'projectId': wrongSnapshot ? otherId : projectId,
              'revisionId': revisionId,
              'blueprint': {'projectId': projectId},
            })
            : '# $name\nApproved project document.';

    final bytes = utf8.encode(text);

    manifestFiles.add({
      'path': name,
      'sizeBytes': bytes.length,
      'sha256':
          badDocumentHash && name == 'README.md'
              ? List.filled(64, '0').join()
              : SecondBrainPackage.hash(bytes),
    });

    if (missingFile && name == 'README.md') {
      continue;
    }

    final entryName =
        unsafeEntry && name == 'README.md' ? '../README.md' : name;

    archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
  }

  final manifest = utf8.encode(
    jsonEncode({
      'format': 'reqviora.second-brain-manifest',
      'schemaVersion': '1.0.0',
      'generatorVersion': '1.0.0',
      'projectId': manifestProject,
      'revisionId': manifestRevision,
      'approvalStatus': approval,
      'referenceCount': manifestFiles.length,
      'files': manifestFiles,
    }),
  );

  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));

  return ZipEncoder().encode(archive);
}

SecondBrainPackage read(List<int> bytes, {String? hash, int? size}) =>
    SecondBrainPackage.read(
      bytes: bytes,
      projectId: projectId,
      revisionId: revisionId,
      expectedSha256: hash ?? SecondBrainPackage.hash(bytes),
      expectedSize: size ?? bytes.length,
    );

void main() {
  test('Reads all 20 approved package documents', () {
    final result = read(createPackage());

    expect(result.documents.length, 20);
    expect(result.projectId, projectId);
    expect(result.revisionId, revisionId);
    expect(result.documents['README.md'], contains('Approved'));
    expect(result.documents['project.json'], isNotNull);
    expect(result.documents['manifest.json'], isNotNull);
  });

  test('Rejects invalid archive signature', () {
    expect(() => read([1, 2, 3, 4]), throwsFormatException);
  });

  test('Rejects incorrect archive size', () {
    final bytes = createPackage();

    expect(() => read(bytes, size: bytes.length + 1), throwsFormatException);
  });

  test('Rejects incorrect archive SHA-256', () {
    final bytes = createPackage();

    expect(
      () => read(bytes, hash: List.filled(64, '0').join()),
      throwsFormatException,
    );
  });

  test('Rejects cross-project manifests', () {
    expect(
      () => read(createPackage(manifestProject: otherId)),
      throwsFormatException,
    );
  });

  test('Rejects mismatched approved revision', () {
    expect(
      () => read(createPackage(manifestRevision: otherId)),
      throwsFormatException,
    );
  });

  test('Rejects unapproved packages', () {
    expect(() => read(createPackage(approval: 'draft')), throwsFormatException);
  });

  test('Rejects tampered document hash', () {
    expect(
      () => read(createPackage(badDocumentHash: true)),
      throwsFormatException,
    );
  });

  test('Rejects unsafe archive paths', () {
    expect(() => read(createPackage(unsafeEntry: true)), throwsFormatException);
  });

  test('Rejects missing required document', () {
    expect(() => read(createPackage(missingFile: true)), throwsFormatException);
  });

  test('Rejects mismatched project snapshot', () {
    expect(
      () => read(createPackage(wrongSnapshot: true)),
      throwsFormatException,
    );
  });

  test('Verified document collection is read-only', () {
    final result = read(createPackage());

    expect(
      () => result.documents['README.md'] = 'Modified',
      throwsUnsupportedError,
    );
  });
}
