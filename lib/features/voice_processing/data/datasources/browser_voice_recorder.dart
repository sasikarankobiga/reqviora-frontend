import 'dart:js_interop';
import 'dart:typed_data';

import 'recorded_audio.dart';

@JS('reqvioraVoiceRecorder.start')
external JSPromise<JSBoolean> _start();

@JS('reqvioraVoiceRecorder.stop')
external JSPromise<_RecordingResult> _stop();

@JS('reqvioraVoiceRecorder.cancel')
external void _cancel();

@JS('reqvioraVoiceRecorder.play')
external JSPromise<JSBoolean> _play(JSUint8Array bytes);

@JS('reqvioraVoiceRecorder.stopPlayback')
external void _stopPlayback();

extension type _RecordingResult(JSObject _) implements JSObject {
  external JSUint8Array get bytes;
  external JSNumber get seconds;
}

class BrowserVoiceRecorder {
  Future<void> start() async {
    await _start().toDart;
  }

  Future<RecordedAudio> stop() async {
    final result = await _stop().toDart;

    return RecordedAudio(
      bytes: result.bytes.toDart,
      durationSeconds: result.seconds.toDartInt,
    );
  }

  Future<void> play(Uint8List bytes) async {
    await _play(bytes.toJS).toDart;
  }

  void stopPlayback() => _stopPlayback();

  void cancel() => _cancel();
}
