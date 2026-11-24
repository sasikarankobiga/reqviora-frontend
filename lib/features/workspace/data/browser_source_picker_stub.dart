import '../domain/source_picker.dart';

class UnsupportedSourcePicker implements SourcePicker {
  @override
  Future<SourceFile?> pick() =>
      Future.error(UnsupportedError('File picker requires Flutter Web'));
}

SourcePicker createSourcePicker() => UnsupportedSourcePicker();
