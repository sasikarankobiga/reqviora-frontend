import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/feature_coverage.dart';
import 'package:reqviora_frontend/features/workspace/domain/navigation_diagnostics.dart';

void main() {
  group('Task 06 feature mapping edge cases', () {
    test('Empty workspace reports zero feature coverage', () {
      final result = FeatureCoverage.calculate([], []);

      expect(result.totalFeatures, 0);
      expect(result.mappedFeatures, 0);
      expect(result.invalidFeatureReferences, 0);
    });

    test('Duplicate mappings on a screen count once', () {
      final result = FeatureCoverage.calculate(
        [
          {'id': 'f1', 'name': 'Login'},
        ],
        [
          {
            'id': 's1',
            'featureIds': ['f1', 'f1'],
          },
        ],
      );

      expect(result.mappedFeatures, 1);
      expect(result.invalidFeatureReferences, 0);
      expect(result.screensWithoutFeatures, 0);
    });

    test('Deleting a feature exposes broken screen references', () {
      final result = FeatureCoverage.calculate(
        [
          {'id': 'f2', 'name': 'Dashboard'},
        ],
        [
          {
            'id': 's1',
            'featureIds': ['f1', 'f2'],
          },
        ],
      );

      expect(result.mappedFeatures, 1);
      expect(result.invalidFeatureReferences, 1);
    });
  });

  group('Task 06 navigation edge cases', () {
    final screens = [
      {'id': 's1', 'name': 'Home'},
      {'id': 's2', 'name': 'Details'},
      {'id': 's3', 'name': 'Settings'},
    ];

    test('Empty routes identify disconnected screens', () {
      final result = NavigationDiagnostics.inspect(screens, []);

      expect(result.brokenRoutes, 0);
      expect(result.disconnectedScreenNames, ['Home', 'Details', 'Settings']);
    });

    test('Deleted destination is reported as broken', () {
      final result = NavigationDiagnostics.inspect(
        [
          {'id': 's1', 'name': 'Home'},
        ],
        [
          {'fromScreenId': 's1', 'toScreenId': 's2', 'trigger': 'tap'},
        ],
      );

      expect(result.brokenRoutes, 1);
    });

    test('Different triggers are not duplicate routes', () {
      final result = NavigationDiagnostics.inspect(screens, [
        {'fromScreenId': 's1', 'toScreenId': 's2', 'trigger': 'tap'},
        {'fromScreenId': 's1', 'toScreenId': 's2', 'trigger': 'submit'},
      ]);

      expect(result.duplicateRoutes, 0);
      expect(result.brokenRoutes, 0);
    });
  });
}
