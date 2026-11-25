import 'dart:typed_data';

class RecordedAudio {
  RecordedAudio({required this.bytes, required this.durationSeconds}) {
    if (bytes.isEmpty || bytes.length > 25000000) {
      throw ArgumentError('Invalid recording size');
    }

    if (durationSeconds < 1 || durationSeconds > 1800) {
      throw ArgumentError('Invalid recording duration');
    }
  }

  final Uint8List bytes;
  final int durationSeconds;

  String get name => 'microphone-recording.webm';
}
