import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/v4_interaction_rule_validator.dart';

void main() {
  final components = <Map<String, dynamic>>[
    {'id': 'button-1', 'type': 'button', 'screenId': 'screen-1'},
    {'id': 'input-1', 'type': 'input', 'screenId': 'screen-1'},
    {'id': 'card-1', 'type': 'card', 'screenId': 'screen-1'},
  ];

  final screens = <Map<String, dynamic>>[
    {'id': 'screen-1', 'name': 'Home'},
    {'id': 'screen-2', 'name': 'Dashboard'},
  ];

  Map<String, dynamic> rule({
    String name = 'Submit action',
    String componentId = 'button-1',
    String trigger = 'onClick',
    String action = 'navigate',
    String targetScreenId = 'screen-2',
    String targetState = '',
    String message = '',
  }) =>
      {
        'name': name,
        'componentId': componentId,
        'trigger': trigger,
        'action': action,
        'targetScreenId': targetScreenId,
        'targetState': targetState,
        'message': message,
      };

  String? check(Map<String, dynamic> value) =>
      V4InteractionRuleValidator.validate(
        rule: value,
        components: components,
        screens: screens,
      );

  test('valid button click navigation', () {
    expect(check(rule()), isNull);
  });

  test('rejects missing rule name', () {
    expect(
      check(rule(name: '')),
      'Rule name is required',
    );
  });

  test('rejects missing source component', () {
    expect(
      check(rule(componentId: '')),
      'Select a source component',
    );
  });

  test('rejects broken component reference', () {
    expect(
      check(rule(componentId: 'missing')),
      'Source component does not exist',
    );
  });

  test('rejects unsupported button trigger', () {
    expect(
      check(rule(trigger: 'onChange')),
      'Unsupported trigger for component type',
    );
  });

  test('rejects invalid navigation destination', () {
    expect(
      check(rule(targetScreenId: 'missing')),
      'Destination screen does not exist',
    );
  });

  test('validates input state transition', () {
    expect(
      check(rule(
        componentId: 'input-1',
        trigger: 'onChange',
        action: 'set-state',
        targetState: 'loading',
      )),
      isNull,
    );
  });

  test('validates message action and unsupported types', () {
    expect(
      check(rule(action: 'show-message', message: 'Saved')),
      isNull,
    );

    expect(
      check(rule(action: 'show-message')),
      'Message text is required',
    );

    expect(
      check(rule(componentId: 'card-1')),
      'Component type does not support interaction triggers',
    );
  });
}
