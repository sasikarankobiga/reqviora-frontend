/// Frontend-only visibility rules.
///
/// These rules control presentation, not authorization.
/// Backend visibility/persistence contracts are not yet confirmed.
class V4VisibilityRules {
  static const modes = <String>{
    'always',
    'role',
    'state',
    'fieldEquals',
  };

  static const states = <String>{
    'default',
    'loading',
    'empty',
    'error',
    'success',
    'disabled',
    'permission-denied',
  };

  static String? validate(Map<String, dynamic>? rule) {
    if (rule == null) return null;

    final mode = (rule['mode'] ?? '').toString();

    if (!modes.contains(mode)) {
      return 'Unsupported visibility condition';
    }

    switch (mode) {
      case 'always':
        return null;

      case 'role':
        if ((rule['role'] ?? '').toString().trim().isEmpty) {
          return 'Role is required';
        }
        return null;

      case 'state':
        if (!states.contains(rule['state'])) {
          return 'Valid UI state is required';
        }
        return null;

      case 'fieldEquals':
        if ((rule['fieldId'] ?? '').toString().trim().isEmpty) {
          return 'Form field ID is required';
        }
        if (!rule.containsKey('equals') || rule['equals'] == null) {
          return 'Expected field value is required';
        }
        return null;
    }

    return 'Unsupported visibility condition';
  }

  static bool isVisible({
    required Map<String, dynamic>? rule,
    String? userRole,
    String uiState = 'default',
    Map<String, dynamic> formValues = const {},
  }) {
    if (rule == null) return true;

    // Invalid conditions must not accidentally reveal an element.
    if (validate(rule) != null) return false;

    switch (rule['mode']) {
      case 'always':
        return true;

      case 'role':
        return userRole != null && userRole == rule['role'];

      case 'state':
        return uiState == rule['state'];

      case 'fieldEquals':
        final fieldId = rule['fieldId'].toString();
        return formValues.containsKey(fieldId) &&
            formValues[fieldId] == rule['equals'];

      default:
        return false;
    }
  }
}
