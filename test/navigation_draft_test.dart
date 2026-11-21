import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/wizard/domain/models/feature_screen_draft.dart';
import 'package:reqviora_frontend/features/wizard/domain/models/navigation_draft.dart';

void main() {
  late FeatureScreenDraft screens;
  late NavigationDraft navigation;

  setUp(() {
    screens = FeatureScreenDraft();
    screens.addScreen('Login Screen');
    screens.addScreen('Dashboard');
    screens.addScreen('SOS Alert');

    navigation = NavigationDraft(
      featureScreens: screens,
    );
  });

  test('Start screen can be selected', () {
    navigation.setStartScreen('Login Screen');

    expect(navigation.startScreen, 'Login Screen');
  });

  test('Unknown start screen is rejected', () {
    expect(
      () => navigation.setStartScreen('Unknown'),
      throwsArgumentError,
    );
  });

  test('Navigation route can be added', () {
    navigation.addRoute(
      source: 'Login Screen',
      destination: 'Dashboard',
      action: 'Login Button',
    );

    expect(navigation.routes.length, 1);
    expect(navigation.routes.first.action, 'Login Button');
  });

  test('Duplicate navigation route is rejected', () {
    navigation.addRoute(
      source: 'Login Screen',
      destination: 'Dashboard',
      action: 'Login Button',
    );

    expect(
      () => navigation.addRoute(
        source: 'Login Screen',
        destination: 'Dashboard',
        action: 'login button',
      ),
      throwsArgumentError,
    );
  });

  test('Unknown screen references are rejected', () {
    expect(
      () => navigation.addRoute(
        source: 'Unknown',
        destination: 'Dashboard',
        action: 'Continue',
      ),
      throwsArgumentError,
    );

    expect(
      () => navigation.addRoute(
        source: 'Login Screen',
        destination: 'Unknown',
        action: 'Continue',
      ),
      throwsArgumentError,
    );
  });

  test('Self navigation and invalid actions are rejected', () {
    expect(
      () => navigation.addRoute(
        source: 'Dashboard',
        destination: 'Dashboard',
        action: 'Continue',
      ),
      throwsArgumentError,
    );

    expect(
      () => navigation.addRoute(
        source: 'Login Screen',
        destination: 'Dashboard',
        action: ' ',
      ),
      throwsArgumentError,
    );
  });

  test('Navigation readiness requires start and route', () {
    expect(navigation.isReady, isFalse);

    navigation.setStartScreen('Login Screen');
    expect(navigation.isReady, isFalse);

    navigation.addRoute(
      source: 'Login Screen',
      destination: 'Dashboard',
      action: 'Login',
    );

    expect(navigation.isReady, isTrue);
  });

  test('Removed screens invalidate affected navigation', () {
    navigation.setStartScreen('Login Screen');

    navigation.addRoute(
      source: 'Login Screen',
      destination: 'Dashboard',
      action: 'Continue',
    );

    screens.removeScreen('Dashboard');

    expect(navigation.routes, isEmpty);
    expect(navigation.isReady, isFalse);

    screens.removeScreen('Login Screen');

    expect(navigation.startScreen, isNull);
  });

  test('Removing route updates navigation readiness', () {
    navigation.setStartScreen('Login Screen');

    navigation.addRoute(
      source: 'Login Screen',
      destination: 'Dashboard',
      action: 'Continue',
    );

    final route = navigation.routes.first;
    navigation.removeRoute(route);

    expect(navigation.routes, isEmpty);
    expect(navigation.isReady, isFalse);
  });
}
