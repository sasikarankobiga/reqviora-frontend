/// Checks the basic structural integrity of a standard ZIP archive.
///
/// This is not a cryptographic integrity check or a substitute for
/// validating the contents of an extracted archive.
/// ZIP64 and multi-disk archives are intentionally unsupported.
bool isStructurallyValidZip(List<int> bytes) {
  if (bytes.length < 22) return false;

  bool signatureAt(int offset, int a, int b, int c, int d) {
    if (offset < 0 || offset + 4 > bytes.length) return false;
    return bytes[offset] == a &&
        bytes[offset + 1] == b &&
        bytes[offset + 2] == c &&
        bytes[offset + 3] == d;
  }

  int u16(int offset) => bytes[offset] | (bytes[offset + 1] << 8);

  int u32(int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  final localHeader = signatureAt(0, 80, 75, 3, 4);
  final emptyHeader = signatureAt(0, 80, 75, 5, 6);

  if (!localHeader && !emptyHeader) return false;

  final lastPosition = bytes.length - 22;
  final firstPosition = bytes.length > 65557 ? bytes.length - 65557 : 0;

  for (var pos = lastPosition; pos >= firstPosition; pos--) {
    if (!signatureAt(pos, 80, 75, 5, 6)) continue;

    final commentLength = u16(pos + 20);
    if (pos + 22 + commentLength != bytes.length) continue;

    // Reject unsupported multi-disk and ZIP64 structures.
    if (u16(pos + 4) != 0 || u16(pos + 6) != 0) {
      return false;
    }

    final diskEntries = u16(pos + 8);
    final totalEntries = u16(pos + 10);
    final directorySize = u32(pos + 12);
    final directoryOffset = u32(pos + 16);

    if (diskEntries != totalEntries ||
        totalEntries == 65535 ||
        directorySize == 0xffffffff ||
        directoryOffset == 0xffffffff) {
      return false;
    }

    if (totalEntries == 0) {
      return emptyHeader &&
          pos == 0 &&
          directorySize == 0 &&
          directoryOffset == 0;
    }

    if (!localHeader ||
        directoryOffset < 30 ||
        directorySize < 46 ||
        directoryOffset + directorySize != pos) {
      return false;
    }

    return signatureAt(directoryOffset, 80, 75, 1, 2);
  }

  return false;
}
