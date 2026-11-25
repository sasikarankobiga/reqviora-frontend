import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/navigation_diagnostics.dart';

void main() {
  final screens = [
    {'id': 's1', 'name': 'Home'},
    {'id': 's2', 'name': 'Details'},
    {'id': 's3', 'name': 'Settings'},
  ];

  test('Valid route has no broken references', () {
    final result = NavigationDiagnostics.inspect(screens, [
      {'fromScreenId': 's1', 'toScreenId': 's2', 'trigger': 'tap'},
    ]);

    expect(result.brokenRoutes, 0);
    expect(result.duplicateRoutes, 0);
  });

  test('Missing screen references are detected', () {
    final result = NavigationDiagnostics.inspect(screens, [
      {'fromScreenId': 's1', 'toScreenId': 'missing', 'trigger': 'tap'},
    ]);

    expect(result.brokenRoutes, 1);
  });

  test('Duplicate navigation connections are detected', () {
    final route = {'fromScreenId': 's1', 'toScreenId': 's2', 'trigger': 'tap'};

    final result = NavigationDiagnostics.inspect(screens, [
      route,
      Map<String, dynamic>.from(route),
    ]);

    expect(result.duplicateRoutes, 1);
  });

  test('Disconnected screens are reported', () {
    final result = NavigationDiagnostics.inspect(screens, [
      {'fromScreenId': 's1', 'toScreenId': 's2', 'trigger': 'tap'},
    ]);

    expect(result.disconnectedScreenNames, ['Settings']);
  });
}
