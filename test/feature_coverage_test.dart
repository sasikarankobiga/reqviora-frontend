import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/feature_coverage.dart';

void main() {
  test('Reports full feature coverage', () {
    final result = FeatureCoverage.calculate(
      [
        {'id': 'f1', 'name': 'Login'},
        {'id': 'f2', 'name': 'Dashboard'},
      ],
      [
        {
          'id': 's1',
          'featureIds': ['f1', 'f2'],
        },
      ],
    );

    expect(result.totalFeatures, 2);
    expect(result.mappedFeatures, 2);
    expect(result.unmappedFeatureNames, isEmpty);
  });

  test('Detects features without screens', () {
    final result = FeatureCoverage.calculate(
      [
        {'id': 'f1', 'name': 'Login'},
        {'id': 'f2', 'name': 'Export'},
      ],
      [
        {
          'id': 's1',
          'featureIds': ['f1'],
        },
      ],
    );

    expect(result.mappedFeatures, 1);
    expect(result.unmappedFeatureNames, ['Export']);
  });

  test('Detects screens without feature mappings', () {
    final result = FeatureCoverage.calculate(
      [
        {'id': 'f1', 'name': 'Login'},
      ],
      [
        {'id': 's1', 'featureIds': []},
      ],
    );

    expect(result.screensWithoutFeatures, 1);
  });

  test('Detects broken feature references', () {
    final result = FeatureCoverage.calculate(
      [
        {'id': 'f1', 'name': 'Login'},
      ],
      [
        {
          'id': 's1',
          'featureIds': ['missing-feature'],
        },
      ],
    );

    expect(result.invalidFeatureReferences, 1);
    expect(result.mappedFeatures, 0);
  });
}
