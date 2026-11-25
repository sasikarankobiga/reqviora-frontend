import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/builder_quality_checks.dart';

void main() {
  final screens = <Map<String, dynamic>>[
    {'id': 'home', 'name': 'Home'},
    {'id': 'details', 'name': 'Details'},
    {'id': 'settings', 'name': 'Settings'},
  ];

  test('Duplicate names are case insensitive', () {
    final result = BuilderQualityChecks.duplicateNames([
      {'name': 'Login'},
      {'name': ' login '},
      {'name': 'Dashboard'},
    ]);

    expect(result, ['Login']);
  });

  test('Unique names report no duplicates', () {
    final result = BuilderQualityChecks.duplicateNames([
      {'name': 'Login'},
      {'name': 'Dashboard'},
    ]);

    expect(result, isEmpty);
  });

  test('Reachable screen chain reports none', () {
    final result = BuilderQualityChecks.unreachableFromEntry(screens, [
      {'fromScreenId': 'home', 'toScreenId': 'details'},
      {'fromScreenId': 'details', 'toScreenId': 'settings'},
    ]);

    expect(result, isEmpty);
  });

  test('Reverse-only navigation is not reachable', () {
    final result = BuilderQualityChecks.unreachableFromEntry(screens, [
      {'fromScreenId': 'details', 'toScreenId': 'home'},
      {'fromScreenId': 'settings', 'toScreenId': 'details'},
    ]);

    expect(result, ['Details', 'Settings']);
  });

  test('Disconnected screen is reported', () {
    final result = BuilderQualityChecks.unreachableFromEntry(screens, [
      {'fromScreenId': 'home', 'toScreenId': 'details'},
    ]);

    expect(result, ['Settings']);
  });

  test('Invalid entry screen is rejected', () {
    expect(
      () => BuilderQualityChecks.unreachableFromEntry(
        screens,
        [],
        entryScreenId: 'missing',
      ),
      throwsArgumentError,
    );
  });
}
