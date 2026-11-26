// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../domain/source_picker.dart';

Future<SourceFile?> pickAudioFile() async {
  final input =
      html.FileUploadInputElement()..accept = '.wav,.mp3,.m4a,.mp4,.webm';

  final selection = Completer<SourceFile?>();

  final change = input.onChange.listen((_) async {
    try {
      final file = input.files?.firstOrNull;

      if (file == null) {
        if (!selection.isCompleted) selection.complete(null);
        return;
      }

      if (file.size <= 0 || file.size > 25000000) {
        throw StateError('Audio must not exceed 25 MB');
      }

      final reader = html.FileReader();

      final loaded = reader.onLoad.first;
      reader.readAsArrayBuffer(file);

      await loaded.timeout(const Duration(seconds: 30));

      final raw = reader.result;

      final bytes = switch (raw) {
        ByteBuffer value => Uint8List.view(value),
        Uint8List value => value,
        _ => throw StateError('Cannot read audio file'),
      };

      if (!selection.isCompleted) {
        selection.complete(SourceFile(file.name, bytes));
      }
    } catch (error, stack) {
      if (!selection.isCompleted) {
        selection.completeError(error, stack);
      }
    }
  });

  final cancel = input.on['cancel'].listen((_) {
    if (!selection.isCompleted) selection.complete(null);
  });

  try {
    input.click();

    return await selection.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => null,
    );
  } finally {
    await change.cancel();
    await cancel.cancel();
  }
}
