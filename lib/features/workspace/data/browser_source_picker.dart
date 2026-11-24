// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import '../domain/source_picker.dart';

/// Browser-only adapter for the Flutter Web authoring client.
class BrowserSourcePicker implements SourcePicker {
  @override
  Future<SourceFile?> pick() async {
    final input = html.FileUploadInputElement()..accept = '.pdf,.docx,.txt';
    input.click();
    await input.onChange.first;
    final file = input.files?.firstOrNull;
    if (file == null) return null;
    if (file.size > 5000000) {
      throw StateError('File exceeds the 5 MB local development limit');
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final raw = reader.result;
    if (raw is ByteBuffer) return SourceFile(file.name, Uint8List.view(raw));
    throw StateError('Unable to read file');
  }
}

SourcePicker createSourcePicker() => BrowserSourcePicker();
