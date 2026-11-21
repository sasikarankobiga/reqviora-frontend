import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/wizard/domain/models/feature_screen_draft.dart';

void main() {
  test('Features and screens can be added', () {
    final draft = FeatureScreenDraft();

    draft.addFeature('Login');
    draft.addScreen('Login Screen');

    expect(draft.features, ['Login']);
    expect(draft.screens, ['Login Screen']);
  });

  test('Duplicate names are rejected', () {
    final draft = FeatureScreenDraft();

    draft.addFeature('Login');
    draft.addScreen('Home Screen');

    expect(() => draft.addFeature('login'), throwsArgumentError);
    expect(() => draft.addScreen('home screen'), throwsArgumentError);
  });

  test('Invalid names are rejected', () {
    final draft = FeatureScreenDraft();

    expect(() => draft.addFeature(' '), throwsArgumentError);
    expect(() => draft.addScreen('A' * 101), throwsArgumentError);
  });

  test('Feature maps to multiple screens', () {
    final draft = FeatureScreenDraft();

    draft.addFeature('Authentication');
    draft.addScreen('Login Screen');
    draft.addScreen('Register Screen');

    draft.mapFeatureToScreen(
      feature: 'Authentication',
      screen: 'Login Screen',
    );

    draft.mapFeatureToScreen(
      feature: 'Authentication',
      screen: 'Register Screen',
    );

    expect(
      draft.mappings['Authentication'],
      {'Login Screen', 'Register Screen'},
    );
  });

  test('Unknown references are rejected', () {
    final draft = FeatureScreenDraft();

    draft.addFeature('Login');
    draft.addScreen('Login Screen');

    expect(
      () => draft.mapFeatureToScreen(
        feature: 'Unknown',
        screen: 'Login Screen',
      ),
      throwsArgumentError,
    );

    expect(
      () => draft.mapFeatureToScreen(
        feature: 'Login',
        screen: 'Unknown Screen',
      ),
      throwsArgumentError,
    );
  });

  test('Removing a screen cleans mappings', () {
    final draft = FeatureScreenDraft();

    draft.addFeature('Login');
    draft.addScreen('Login Screen');

    draft.mapFeatureToScreen(
      feature: 'Login',
      screen: 'Login Screen',
    );

    draft.removeScreen('Login Screen');

    expect(draft.screens, isEmpty);
    expect(draft.mappings['Login'], isEmpty);
  });

  test('Removing a feature cleans mappings', () {
    final draft = FeatureScreenDraft();

    draft.addFeature('Login');
    draft.removeFeature('Login');

    expect(draft.features, isEmpty);
    expect(draft.mappings.containsKey('Login'), isFalse);
  });

  test('Readiness requires features and screens', () {
    final draft = FeatureScreenDraft();

    expect(draft.hasFeaturesAndScreens, isFalse);

    draft.addFeature('Login');
    expect(draft.hasFeaturesAndScreens, isFalse);

    draft.addScreen('Login Screen');
    expect(draft.hasFeaturesAndScreens, isTrue);
  });
}
