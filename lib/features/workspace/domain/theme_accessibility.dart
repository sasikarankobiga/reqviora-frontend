import 'dart:math';

double contrastRatio(String foreground, String background) {
  int parseColor(String value) {
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      throw FormatException('Expected a #RRGGBB color');
    }
    return int.parse(value.substring(1), radix: 16);
  }

  double luminance(String value) {
    final rgb = parseColor(value);

    double linear(int component) {
      final channel = component / 255.0;
      return channel <= 0.04045
          ? channel / 12.92
          : pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final red = linear((rgb >> 16) & 255);
    final green = linear((rgb >> 8) & 255);
    final blue = linear(rgb & 255);

    return 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }

  final first = luminance(foreground);
  final second = luminance(background);

  return (max(first, second) + 0.05) / (min(first, second) + 0.05);
}

bool meetsNormalTextContrast(String foreground, String background) {
  return contrastRatio(foreground, background) >= 4.5;
}
