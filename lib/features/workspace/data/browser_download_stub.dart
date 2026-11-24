import '../domain/download_port.dart';

class UnsupportedDownload implements DownloadPort {
  @override
  void saveZip(String filename, List<int> bytes) =>
      throw UnsupportedError('ZIP download requires Flutter Web');
}

DownloadPort createDownloader() => UnsupportedDownload();
