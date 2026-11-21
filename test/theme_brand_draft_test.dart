import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/wizard/domain/models/theme_brand_draft.dart';

void main() {
  test('Default theme values are valid', () {
    final draft = ThemeBrandDraft();

    expect(draft.theme, ThemePreference.light);
    expect(draft.fontFamily, 'Roboto');
    expect(draft.isValid, isTrue);
  });

  test('Theme and brand details can be updated', () {
    final draft = ThemeBrandDraft();

    draft.update(
      theme: ThemePreference.dark,
      brandName: ' Student Safety ',
      primaryColor: '#123abc',
      secondaryColor: '#AABBCC',
      fontFamily: 'Inter',
    );

    expect(draft.theme, ThemePreference.dark);
    expect(draft.brandName, 'Student Safety');
    expect(draft.primaryColor, '#123ABC');
    expect(draft.secondaryColor, '#AABBCC');
    expect(draft.fontFamily, 'Inter');
  });

  test('Invalid primary color is rejected', () {
    final draft = ThemeBrandDraft();

    expect(
      () => draft.update(
        theme: ThemePreference.light,
        brandName: 'Test Brand',
        primaryColor: 'red',
        secondaryColor: '#14B8A6',
        fontFamily: 'Roboto',
      ),
      throwsArgumentError,
    );
  });

  test('Invalid secondary color is rejected', () {
    final draft = ThemeBrandDraft();

    expect(
      () => draft.update(
        theme: ThemePreference.light,
        brandName: 'Test Brand',
        primaryColor: '#2563EB',
        secondaryColor: '#XYZ123',
        fontFamily: 'Roboto',
      ),
      throwsArgumentError,
    );
  });

  test('Unsupported font is rejected', () {
    final draft = ThemeBrandDraft();

    expect(
      () => draft.update(
        theme: ThemePreference.light,
        brandName: 'Test Brand',
        primaryColor: '#2563EB',
        secondaryColor: '#14B8A6',
        fontFamily: 'Unknown Font',
      ),
      throwsArgumentError,
    );
  });

  test('Brand name length is validated', () {
    final draft = ThemeBrandDraft();

    expect(
      () => draft.update(
        theme: ThemePreference.light,
        brandName: 'A',
        primaryColor: '#2563EB',
        secondaryColor: '#14B8A6',
        fontFamily: 'Roboto',
      ),
      throwsArgumentError,
    );
  });

  test('Invalid update preserves existing theme data', () {
    final draft = ThemeBrandDraft();

    expect(
      () => draft.update(
        theme: ThemePreference.dark,
        brandName: 'Updated Brand',
        primaryColor: 'invalid',
        secondaryColor: '#14B8A6',
        fontFamily: 'Inter',
      ),
      throwsArgumentError,
    );

    expect(draft.theme, ThemePreference.light);
    expect(draft.brandName, isEmpty);
    expect(draft.primaryColor, '#2563EB');
    expect(draft.fontFamily, 'Roboto');
  });
}
