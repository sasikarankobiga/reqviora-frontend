import 'dart:typed_data';

class SourceFile {
  const SourceFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
abstract interface class SourcePicker {
  Future<SourceFile?> pick();
}
