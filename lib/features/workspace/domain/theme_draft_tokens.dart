/// Builds the theme section sent to the draft repository.
///
/// Unknown existing tokens are retained so an edit does not silently
/// discard design settings introduced by other Builder versions.
Map<String, dynamic> buildThemeDraftTokens({
  required Map<String, dynamic> existing,
  required String primaryColor,
  required String secondaryColor,
  required String mode,
  required String fontFamily,
  required int baseSpacing,
  required int borderRadius,
}) {
  return {
    ...existing,
    'primaryColor': primaryColor,
    'secondaryColor': secondaryColor,
    'mode': mode,
    'fontFamily': fontFamily,
    'baseSpacing': baseSpacing,
    'borderRadius': borderRadius,
  };
}
