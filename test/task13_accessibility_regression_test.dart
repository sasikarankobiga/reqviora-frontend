import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/theme_accessibility.dart';

void main() {
  group('Task 13 WCAG AA contrast regression', () {
    test('Black and white satisfy normal text contrast', () {
      expect(meetsNormalTextContrast('#000000', '#FFFFFF'), isTrue);
      expect(meetsNormalTextContrast('#FFFFFF', '#000000'), isTrue);
    });

    test('Low contrast white on light gray fails', () {
      expect(meetsNormalTextContrast('#FFFFFF', '#EEEEEE'), isFalse);
    });

    test('WCAG AA normal text boundary is 4.5', () {
      // #767676 on white is approximately 4.54:1.
      expect(meetsNormalTextContrast('#767676', '#FFFFFF'), isTrue);

      // #777777 on white is approximately 4.48:1.
      expect(meetsNormalTextContrast('#777777', '#FFFFFF'), isFalse);
    });

    test('Foreground and background contrast are symmetric', () {
      final forward = contrastRatio('#123456', '#ABCDEF');
      final reverse = contrastRatio('#ABCDEF', '#123456');
      expect(forward, closeTo(reverse, 0.000001));
    });

    test('Invalid CSS color input cannot silently pass', () {
      expect(
        () => meetsNormalTextContrast('blue', '#FFFFFF'),
        throwsFormatException,
      );
      expect(
        () => meetsNormalTextContrast('#FFF', '#FFFFFF'),
        throwsFormatException,
      );
    });
  });
}
