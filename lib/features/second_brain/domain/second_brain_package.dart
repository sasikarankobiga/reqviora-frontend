import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class SecondBrainPackage {
  const SecondBrainPackage._({
    required this.projectId,
    required this.revisionId,
    required this.documents,
  });

  final String projectId;
  final String revisionId;
  final Map<String, String> documents;

  static const referenceNames = [
    'README.md',
    'project-overview.md',
    'goals-and-success-criteria.md',
    'audience-and-roles.md',
    'scope-and-constraints.md',
    'feature-catalog.md',
    'business-rules-and-acceptance.md',
    'screen-specifications.md',
    'feature-screen-mapping.md',
    'navigation-and-journeys.md',
    'design-tokens.md',
    'components-and-layout.md',
    'interactions-and-states.md',
    'accessibility-requirements.md',
    'decision-register.md',
    'open-questions.md',
    'validation-report.md',
    'implementation-checklist.md',
    'project.json',
  ];

  static const maxArchiveBytes = 16 * 1024 * 1024;
  static const maxFileBytes = 8 * 1024 * 1024;
  static const maxExpandedBytes = 32 * 1024 * 1024;

  static String hash(List<int> bytes) => sha256.convert(bytes).toString();

  static bool sameId(dynamic actual, String expected) =>
      actual is String && actual.toLowerCase() == expected.toLowerCase();

  static bool validGuid(String value) =>
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value) &&
      value != '00000000-0000-0000-0000-000000000000';

  static SecondBrainPackage read({
    required List<int> bytes,
    required String projectId,
    required String revisionId,
    required String expectedSha256,
    required int expectedSize,
  }) {
    if (!validGuid(projectId) || !validGuid(revisionId)) {
      throw const FormatException('Invalid package identity.');
    }

    if (bytes.length < 4 ||
        bytes.length > maxArchiveBytes ||
        bytes.length != expectedSize ||
        bytes[0] != 0x50 ||
        bytes[1] != 0x4B ||
        bytes[2] != 0x03 ||
        bytes[3] != 0x04) {
      throw const FormatException('Invalid archive size or signature.');
    }

    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha256) ||
        hash(bytes) != expectedSha256.toLowerCase()) {
      throw const FormatException('Archive integrity check failed.');
    }

    final allowed = {...referenceNames, 'manifest.json'};

    final archive = ZipDecoder().decodeBytes(bytes);

    if (archive.length != allowed.length) {
      throw const FormatException('Unexpected archive entry count.');
    }

    final entries = <String, ArchiveFile>{};
    var totalSize = 0;

    // Inspect declared sizes and file names before reading contents.
    // Never extract these entries to the filesystem.
    for (final file in archive) {
      if (!file.isFile ||
          file.isSymbolicLink ||
          !allowed.contains(file.name) ||
          entries.containsKey(file.name) ||
          file.size < 0 ||
          file.size > maxFileBytes) {
        throw const FormatException('Unsafe archive entry.');
      }

      totalSize += file.size;

      if (totalSize > maxExpandedBytes) {
        throw const FormatException('Package expansion limit exceeded.');
      }

      entries[file.name] = file;
    }

    final documents = <String, String>{};

    List<int> readEntry(String name) {
      final entry = entries[name];

      if (entry == null) {
        throw const FormatException('Required document is missing.');
      }

      final content = entry.content;

      if (content.length != entry.size || content.length > maxFileBytes) {
        throw const FormatException('Invalid document size.');
      }

      return content;
    }

    final manifestText = utf8.decode(readEntry('manifest.json'));
    final manifest = jsonDecode(manifestText);

    if (manifest is! Map ||
        manifest['format'] != 'reqviora.second-brain-manifest' ||
        manifest['schemaVersion'] != '1.0.0' ||
        manifest['generatorVersion'] != '1.0.0' ||
        manifest['approvalStatus'] != 'approved' ||
        !sameId(manifest['projectId'], projectId) ||
        !sameId(manifest['revisionId'], revisionId) ||
        manifest['referenceCount'] != referenceNames.length ||
        manifest['files'] is! List) {
      throw const FormatException('Invalid Second Brain manifest.');
    }

    final files = manifest['files'] as List;

    if (files.length != referenceNames.length) {
      throw const FormatException('Invalid manifest file count.');
    }

    for (var i = 0; i < referenceNames.length; i++) {
      final name = referenceNames[i];
      final metadata = files[i];

      if (metadata is! Map ||
          metadata['path'] != name ||
          metadata['sizeBytes'] is! int ||
          metadata['sha256'] is! String) {
        throw const FormatException('Invalid document metadata.');
      }

      final content = readEntry(name);

      if (metadata['sizeBytes'] != content.length ||
          metadata['sha256'] != hash(content)) {
        throw const FormatException('Document integrity check failed.');
      }

      documents[name] = utf8.decode(content);
    }

    final snapshot = jsonDecode(documents['project.json']!);

    if (snapshot is! Map ||
        !sameId(snapshot['projectId'], projectId) ||
        !sameId(snapshot['revisionId'], revisionId) ||
        snapshot['blueprint'] is! Map ||
        !sameId(snapshot['blueprint']['projectId'], projectId)) {
      throw const FormatException('Invalid approved project snapshot.');
    }

    documents['manifest.json'] = manifestText;

    return SecondBrainPackage._(
      projectId: projectId,
      revisionId: revisionId,
      documents: Map.unmodifiable(documents),
    );
  }
}
