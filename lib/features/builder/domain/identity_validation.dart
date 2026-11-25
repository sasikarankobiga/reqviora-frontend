// Step 01 validation aligned with Create Project limits.

String? validateIdentityName(String? value) {
  final name = (value ?? '').trim();

  if (name.isEmpty) {
    return 'Project name is required';
  }

  if (name.length > 160) {
    return 'Project name must not exceed 160 characters';
  }

  return null;
}

String? validateIdentityDescription(String? value) {
  if ((value ?? '').trim().length > 10000) {
    return 'Description must not exceed 10000 characters';
  }

  return null;
}
