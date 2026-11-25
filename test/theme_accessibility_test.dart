import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/theme_accessibility.dart';

void main() {
  test('Black on white has maximum contrast', () {
    expect(contrastRatio('#000000', '#FFFFFF'), closeTo(21, 0.01));
  });

  test('Same colors have minimum contrast', () {
    expect(contrastRatio('#123456', '#123456'), closeTo(1, 0.01));
  });

  test('Normal text contrast follows AA threshold', () {
    expect(meetsNormalTextContrast('#000000', '#FFFFFF'), true);
    expect(meetsNormalTextContrast('#FFFFFF', '#FFFFFF'), false);
  });

  test('Malformed colors are rejected', () {
    expect(() => contrastRatio('purple', '#FFFFFF'), throwsFormatException);
  });
}
