/// Parses role labels entered in the Screen Editor.
///
/// An empty list means no role restriction was configured in
/// the design metadata. Authorization belongs to the backend.
List<String> parseScreenAccessRoles(String input) {
  return input
      .split(',')
      .map((role) => role.trim())
      .where((role) => role.isNotEmpty)
      .toSet()
      .toList();
}
