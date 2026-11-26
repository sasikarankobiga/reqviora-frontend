import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/screen_access_roles.dart';

void main() {
  test('Parses comma-separated screen roles', () {
    expect(parseScreenAccessRoles('Admin, Manager, User'), [
      'Admin',
      'Manager',
      'User',
    ]);
  });

  test('Trims whitespace, removes empty values and duplicates', () {
    expect(parseScreenAccessRoles(' Admin , , Manager, Admin,  User  ,'), [
      'Admin',
      'Manager',
      'User',
    ]);
  });

  test('Empty input represents unrestricted design metadata', () {
    expect(parseScreenAccessRoles(' , , '), isEmpty);
  });
}
