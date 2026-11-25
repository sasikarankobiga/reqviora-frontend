class FeatureCoverage {
  const FeatureCoverage({
    required this.totalFeatures,
    required this.mappedFeatures,
    required this.unmappedFeatureNames,
    required this.screensWithoutFeatures,
    required this.invalidFeatureReferences,
  });

  final int totalFeatures;
  final int mappedFeatures;
  final List<String> unmappedFeatureNames;
  final int screensWithoutFeatures;
  final int invalidFeatureReferences;

  static FeatureCoverage calculate(
    List<Map<String, dynamic>> features,
    List<Map<String, dynamic>> screens,
  ) {
    final featureIds = features.map((f) => f['id'].toString()).toSet();
    final mappedIds = <String>{};
    var emptyScreens = 0;
    var invalidReferences = 0;

    for (final screen in screens) {
      final raw = screen['featureIds'];
      final ids =
          raw is List
              ? raw.map((value) => value.toString()).toSet()
              : <String>{};

      if (ids.isEmpty) {
        emptyScreens++;
      }

      for (final id in ids) {
        if (featureIds.contains(id)) {
          mappedIds.add(id);
        } else {
          invalidReferences++;
        }
      }
    }

    final unmappedNames = <String>[];

    for (final feature in features) {
      if (!mappedIds.contains(feature['id'].toString())) {
        unmappedNames.add((feature['name'] ?? 'Unnamed feature').toString());
      }
    }

    return FeatureCoverage(
      totalFeatures: features.length,
      mappedFeatures: mappedIds.length,
      unmappedFeatureNames: unmappedNames,
      screensWithoutFeatures: emptyScreens,
      invalidFeatureReferences: invalidReferences,
    );
  }
}
