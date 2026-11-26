import 'dart:typed_data';

import 'recorded_audio.dart';

class BrowserVoiceRecorder {
  Future<void> start() async {
    throw UnsupportedError('Microphone recording is available in the browser.');
  }

  Future<RecordedAudio> stop() async {
    throw UnsupportedError('No active browser recording.');
  }

  Future<void> play(Uint8List bytes) async {
    throw UnsupportedError('Browser playback is unavailable.');
  }

  void stopPlayback() {}

  void cancel() {}
}
