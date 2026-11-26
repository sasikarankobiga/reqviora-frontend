import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/zip_archive_check.dart';

void main() {
  const emptyZip = <int>[
    80,
    75,
    5,
    6,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  // Standard ZIP containing one empty file named handoff.txt.
  final fileZip = base64Decode(
    'UEsDBBQAAAAAABgcel0AAAAAAAAAAAAAAAALAAAAaGFuZG9mZi50eHRQ'
    'SwECFAMUAAAAAAAYHHpdAAAAAAAAAAAAAAAACwAAAAAAAAAAAAAAgAEA'
    'AAAAaGFuZG9mZi50eHRQSwUGAAAAAAEAAQA5AAAAKQAAAAAA',
  );

  test('Valid empty ZIP is accepted', () {
    expect(isStructurallyValidZip(emptyZip), isTrue);
  });

  test('Valid non-empty ZIP is accepted', () {
    expect(isStructurallyValidZip(fileZip), isTrue);
  });

  test('Truncated ZIP is rejected', () {
    final truncated = fileZip.sublist(0, fileZip.length - 8);
    expect(isStructurallyValidZip(truncated), isFalse);
  });

  test('Forged ZIP header without directory is rejected', () {
    final fake = <int>[80, 75, 3, 4, ...List<int>.filled(40, 0)];
    expect(isStructurallyValidZip(fake), isFalse);
  });

  test('Broken central directory offset is rejected', () {
    final broken = List<int>.from(fileZip);

    // EOCD offset is 22 bytes before the end.
    final endRecord = broken.length - 22;

    // Set central directory offset to zero.
    for (var i = 16; i < 20; i++) {
      broken[endRecord + i] = 0;
    }

    expect(isStructurallyValidZip(broken), isFalse);
  });

  test('Invalid ZIP header is rejected', () {
    expect(isStructurallyValidZip([1, 2, 3, 4]), isFalse);
  });
}
