import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/auth/domain/auth_validation.dart';

void main() {
  group('Email validation', () {
    test('Rejects empty email', () {
      expect(AuthValidation.validateEmail(''), isNotNull);
    });

    test('Rejects invalid email', () {
      expect(AuthValidation.validateEmail('invalid-email'), isNotNull);
    });

    test('Accepts valid email', () {
      expect(AuthValidation.validateEmail('user@example.com'), isNull);
    });

    test('Accepts email with surrounding spaces', () {
      expect(AuthValidation.validateEmail(' user@example.com '), isNull);
    });
  });

  group('Password validation', () {
    test('Rejects empty password', () {
      expect(AuthValidation.validatePassword(''), isNotNull);
    });

    test('Rejects short password', () {
      expect(AuthValidation.validatePassword('12345678'), isNotNull);
    });

    test('Accepts a password with 12 characters', () {
      expect(AuthValidation.validatePassword('StrongPass12'), isNull);
    });
  });

  group('Confirm password validation', () {
    test('Rejects empty confirmation', () {
      expect(
        AuthValidation.validateConfirmPassword('', 'StrongPass12'),
        isNotNull,
      );
    });

    test('Rejects mismatching passwords', () {
      expect(
        AuthValidation.validateConfirmPassword('WrongPassword', 'StrongPass12'),
        isNotNull,
      );
    });

    test('Accepts matching passwords', () {
      expect(
        AuthValidation.validateConfirmPassword('StrongPass12', 'StrongPass12'),
        isNull,
      );
    });
  });
}
