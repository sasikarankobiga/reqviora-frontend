// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import '../domain/download_port.dart';

class BrowserDownload implements DownloadPort {
  @override
  void saveZip(String filename, List<int> bytes) {
    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

DownloadPort createDownloader() => BrowserDownload();
