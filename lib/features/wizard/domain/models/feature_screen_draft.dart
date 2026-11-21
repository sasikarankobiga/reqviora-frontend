class FeatureScreenDraft {
  final List<String> _features = [];
  final List<String> _screens = [];
  final Map<String, Set<String>> _mappings = {};

  List<String> get features => List.unmodifiable(_features);
  List<String> get screens => List.unmodifiable(_screens);

  Map<String, Set<String>> get mappings => Map.unmodifiable(
        _mappings.map(
          (key, value) => MapEntry(key, Set.unmodifiable(value)),
        ),
      );

  String _validateName(String value) {
    final name = value.trim();

    if (name.length < 2 || name.length > 100) {
      throw ArgumentError('Name must contain 2 to 100 characters');
    }

    return name;
  }

  void addFeature(String value) {
    final name = _validateName(value);

    if (_features.any((item) => item.toLowerCase() == name.toLowerCase())) {
      throw ArgumentError('Feature already exists');
    }

    _features.add(name);
    _mappings[name] = <String>{};
  }

  void addScreen(String value) {
    final name = _validateName(value);

    if (_screens.any((item) => item.toLowerCase() == name.toLowerCase())) {
      throw ArgumentError('Screen already exists');
    }

    _screens.add(name);
  }

  void mapFeatureToScreen({
    required String feature,
    required String screen,
  }) {
    if (!_features.contains(feature)) {
      throw ArgumentError('Unknown feature');
    }

    if (!_screens.contains(screen)) {
      throw ArgumentError('Unknown screen');
    }

    _mappings[feature]!.add(screen);
  }

  void removeFeature(String feature) {
    if (!_features.remove(feature)) {
      throw ArgumentError('Unknown feature');
    }

    _mappings.remove(feature);
  }

  void removeScreen(String screen) {
    if (!_screens.remove(screen)) {
      throw ArgumentError('Unknown screen');
    }

    for (final mappedScreens in _mappings.values) {
      mappedScreens.remove(screen);
    }
  }

  bool get hasFeaturesAndScreens => _features.isNotEmpty && _screens.isNotEmpty;
}
