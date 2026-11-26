import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/voice_processing/data/datasources/recorded_audio.dart';
import 'package:reqviora_frontend/features/voice_processing/data/datasources/browser_voice_recorder_stub.dart';

void main() {
  test('Recording uses backend-compatible WebM filename', () {
    final result = RecordedAudio(
      bytes: Uint8List.fromList([1, 2, 3]),
      durationSeconds: 10,
    );

    expect(result.name, 'microphone-recording.webm');
    expect(result.durationSeconds, 10);
    expect(result.bytes.length, 3);
  });

  test('Empty recording is rejected', () {
    expect(
      () => RecordedAudio(bytes: Uint8List(0), durationSeconds: 1),
      throwsArgumentError,
    );
  });

  test('Recording above 25 MB is rejected', () {
    expect(
      () => RecordedAudio(bytes: Uint8List(25000001), durationSeconds: 10),
      throwsArgumentError,
    );
  });

  test('Zero recording duration is rejected', () {
    expect(
      () => RecordedAudio(bytes: Uint8List(1), durationSeconds: 0),
      throwsArgumentError,
    );
  });

  test('Recording above thirty minutes is rejected', () {
    expect(
      () => RecordedAudio(bytes: Uint8List(1), durationSeconds: 1801),
      throwsArgumentError,
    );
  });

  test('Maximum supported duration is accepted', () {
    final recording = RecordedAudio(bytes: Uint8List(1), durationSeconds: 1800);

    expect(recording.durationSeconds, 1800);
  });

  test('Non-browser recorder rejects microphone start safely', () async {
    final recorder = BrowserVoiceRecorder();

    await expectLater(recorder.start(), throwsUnsupportedError);

    recorder.cancel();
    recorder.stopPlayback();
  });
}
