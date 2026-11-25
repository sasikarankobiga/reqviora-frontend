import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/identity_validation.dart';

void main() {
  test('Project name is required', () {
    expect(validateIdentityName('   '), 'Project name is required');
  });

  test('Valid project name is accepted', () {
    expect(validateIdentityName('REQVIORA'), isNull);
  });

  test('Long project names are rejected', () {
    expect(validateIdentityName('A' * 161), isNotNull);
    expect(validateIdentityName('A' * 160), isNull);
  });

  test('Description respects Create Project limit', () {
    expect(validateIdentityDescription('A' * 10000), isNull);
    expect(validateIdentityDescription('A' * 10001), isNotNull);
    expect(validateIdentityDescription(''), isNull);
  });
}
