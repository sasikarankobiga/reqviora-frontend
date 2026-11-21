enum ThemePreference {
  light,
  dark,
  system,
}

class ThemeBrandDraft {
  ThemePreference theme = ThemePreference.light;

  String brandName = '';
  String primaryColor = '#2563EB';
  String secondaryColor = '#14B8A6';
  String fontFamily = 'Roboto';

  static const supportedFonts = <String>[
    'Roboto',
    'Inter',
    'Poppins',
    'Open Sans',
  ];

  static final RegExp _hexColorPattern = RegExp(
    r'^#[0-9A-Fa-f]{6}$',
  );

  void update({
    required ThemePreference theme,
    required String brandName,
    required String primaryColor,
    required String secondaryColor,
    required String fontFamily,
  }) {
    final name = brandName.trim();
    final primary = primaryColor.trim().toUpperCase();
    final secondary = secondaryColor.trim().toUpperCase();

    if (name.isNotEmpty && (name.length < 2 || name.length > 80)) {
      throw ArgumentError(
        'Brand name must contain 2 to 80 characters',
      );
    }

    if (!_hexColorPattern.hasMatch(primary)) {
      throw ArgumentError('Invalid primary color');
    }

    if (!_hexColorPattern.hasMatch(secondary)) {
      throw ArgumentError('Invalid secondary color');
    }

    if (!supportedFonts.contains(fontFamily)) {
      throw ArgumentError('Unsupported font family');
    }

    this.theme = theme;
    this.brandName = name;
    this.primaryColor = primary;
    this.secondaryColor = secondary;
    this.fontFamily = fontFamily;
  }

  bool get isValid =>
      _hexColorPattern.hasMatch(primaryColor) &&
      _hexColorPattern.hasMatch(secondaryColor) &&
      supportedFonts.contains(fontFamily);
}
