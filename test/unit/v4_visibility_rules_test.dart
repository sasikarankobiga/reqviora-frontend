import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/v4_visibility_rules.dart';

void main() {
  test('components without conditions remain visible', () {
    expect(V4VisibilityRules.isVisible(rule: null), isTrue);
  });

  test('always condition is visible', () {
    expect(
      V4VisibilityRules.isVisible(rule: {'mode': 'always'}),
      isTrue,
    );
  });

  test('admin role can see restricted component', () {
    final rule = {'mode': 'role', 'role': 'admin'};

    expect(
      V4VisibilityRules.isVisible(rule: rule, userRole: 'admin'),
      isTrue,
    );
    expect(
      V4VisibilityRules.isVisible(rule: rule, userRole: 'viewer'),
      isFalse,
    );
    expect(
      V4VisibilityRules.isVisible(rule: rule),
      isFalse,
    );
  });

  test('component appears only for matching UI state', () {
    final rule = {'mode': 'state', 'state': 'success'};

    expect(
      V4VisibilityRules.isVisible(rule: rule, uiState: 'success'),
      isTrue,
    );
    expect(
      V4VisibilityRules.isVisible(rule: rule, uiState: 'loading'),
      isFalse,
    );
  });

  test('form value controls visibility', () {
    final rule = {
      'mode': 'fieldEquals',
      'fieldId': 'accountType',
      'equals': 'business',
    };

    expect(
      V4VisibilityRules.isVisible(
        rule: rule,
        formValues: {'accountType': 'business'},
      ),
      isTrue,
    );
    expect(
      V4VisibilityRules.isVisible(
        rule: rule,
        formValues: {'accountType': 'personal'},
      ),
      isFalse,
    );
  });

  test('missing form field does not match null', () {
    final rule = {
      'mode': 'fieldEquals',
      'fieldId': 'optional',
      'equals': null,
    };

    expect(V4VisibilityRules.validate(rule), isNotNull);
    expect(V4VisibilityRules.isVisible(rule: rule), isFalse);
  });

  test('unknown condition is rejected', () {
    final rule = {'mode': 'execute-code'};

    expect(
      V4VisibilityRules.validate(rule),
      'Unsupported visibility condition',
    );
    expect(
      V4VisibilityRules.isVisible(rule: rule),
      isFalse,
    );
  });

  test('incomplete conditions fail validation', () {
    expect(
      V4VisibilityRules.validate({'mode': 'role'}),
      'Role is required',
    );
    expect(
      V4VisibilityRules.validate({
        'mode': 'state',
        'state': 'unknown',
      }),
      'Valid UI state is required',
    );
    expect(
      V4VisibilityRules.validate({'mode': 'fieldEquals'}),
      'Form field ID is required',
    );
  });
}
