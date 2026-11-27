import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hand-authored Dart source contains no common mojibake markers', () {
    const markers = ['Ã', 'Â', 'â€™', 'â€“', 'â€”', 'ðŸ', '�'];
    final failures = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final marker in markers) {
        if (source.contains(marker)) {
          failures.add('${file.path}: $marker');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
