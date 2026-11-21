import 'feature_screen_draft.dart';

class NavigationRouteDraft {
  const NavigationRouteDraft({
    required this.source,
    required this.destination,
    required this.action,
  });

  final String source;
  final String destination;
  final String action;
}

class NavigationDraft {
  NavigationDraft({required this.featureScreens});

  final FeatureScreenDraft featureScreens;

  String? _startScreen;
  final List<NavigationRouteDraft> _routes = [];

  String? get startScreen =>
      featureScreens.screens.contains(_startScreen) ? _startScreen : null;

  List<NavigationRouteDraft> get routes => List.unmodifiable(
        _routes.where(
          (route) =>
              featureScreens.screens.contains(route.source) &&
              featureScreens.screens.contains(route.destination),
        ),
      );

  void setStartScreen(String screen) {
    if (!featureScreens.screens.contains(screen)) {
      throw ArgumentError('Unknown start screen');
    }

    _startScreen = screen;
  }

  void addRoute({
    required String source,
    required String destination,
    required String action,
  }) {
    if (!featureScreens.screens.contains(source)) {
      throw ArgumentError('Unknown source screen');
    }

    if (!featureScreens.screens.contains(destination)) {
      throw ArgumentError('Unknown destination screen');
    }

    if (source == destination) {
      throw ArgumentError('Source and destination must differ');
    }

    final normalizedAction = action.trim();

    if (normalizedAction.length < 2 || normalizedAction.length > 100) {
      throw ArgumentError(
        'Action must contain 2 to 100 characters',
      );
    }

    final duplicate = routes.any(
      (route) =>
          route.source == source &&
          route.destination == destination &&
          route.action.toLowerCase() == normalizedAction.toLowerCase(),
    );

    if (duplicate) {
      throw ArgumentError('Navigation route already exists');
    }

    _routes.add(
      NavigationRouteDraft(
        source: source,
        destination: destination,
        action: normalizedAction,
      ),
    );
  }

  void removeRoute(NavigationRouteDraft route) {
    if (!_routes.remove(route)) {
      throw ArgumentError('Navigation route not found');
    }
  }

  bool get isReady => startScreen != null && routes.isNotEmpty;
}
