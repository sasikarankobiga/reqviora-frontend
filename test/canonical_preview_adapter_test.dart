import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/workspace/domain/canonical_preview_adapter.dart';

Map<String, dynamic> canonical() => {
  'screens': [
    {'id': 'SCR-ONE', 'name': 'First screen'},
    {'id': 'SCR-TWO', 'name': 'Second screen'},
  ],
  'components': [
    {
      'id': 'CMP-BUTTON',
      'screenId': 'SCR-ONE',
      'type': 'Button',
      'properties': {'label': 'Continue'},
    },
  ],
  'actions': [
    {
      'id': 'ACT-NEXT',
      'componentId': 'CMP-BUTTON',
      'kind': 'navigate',
      'navigationId': 'NAV-NEXT',
    },
  ],
  'navigation': <Map<String, dynamic>>[
    {
      'id': 'NAV-NEXT',
      'sourceScreenId': 'SCR-ONE',
      'targetScreenId': 'SCR-TWO',
      'actionId': 'ACT-NEXT',
    },
  ],
};

void main() {
  test('Canonical screen IDs are adapted', () {
    final result = adaptCanonicalPreview(canonical());
    expect(result['screens'][0]['screenId'], 'SCR-ONE');
  });

  test('Canonical components are mapped', () {
    final result = adaptCanonicalPreview(canonical());
    final component = result['componentInstances'][0];

    expect(component['type'], 'button');
    expect(component['componentInstanceId'], 'CMP-BUTTON');
    expect(component['props']['label'], 'Continue');
  });

  test('Valid navigation produces local interaction', () {
    final result = adaptCanonicalPreview(canonical());

    expect(result['interactions'], hasLength(1));
    expect(result['interactions'][0]['targetScreenId'], 'SCR-TWO');
  });

  test('Invalid navigation targets are rejected', () {
    final value = canonical();
    value['navigation'][0]['targetScreenId'] = 'MISSING';

    final result = adaptCanonicalPreview(value);

    expect(result['routes'], isEmpty);
    expect(result['interactions'], isEmpty);
  });

  test('Original canonical data remains unchanged', () {
    final value = canonical();

    adaptCanonicalPreview(value);

    expect(value['screens'][0].containsKey('screenId'), isFalse);
    expect(value['components'][0]['type'], 'Button');
    expect(value.containsKey('componentInstances'), isFalse);
  });

  test('Existing visual drafts remain unchanged', () {
    final draft = <String, dynamic>{
      'screens': [
        {'screenId': 'local', 'name': 'Local screen'},
      ],
      'componentInstances': [],
    };

    expect(adaptCanonicalPreview(draft), same(draft));
  });

  test('Duplicate and malformed screens are ignored', () {
    final value = canonical();

    value['screens'] = [
      {'id': 'SCR-ONE', 'name': 'Original'},
      {'id': 'SCR-ONE', 'name': 'Duplicate'},
      {'id': ''},
      123,
    ];

    final result = adaptCanonicalPreview(value);

    expect(result['screens'], hasLength(1));
    expect(result['screens'][0]['name'], 'Original');
  });

  test('Unknown actions are not executable', () {
    final value = canonical();
    value['actions'][0]['kind'] = 'execute-code';

    expect(adaptCanonicalPreview(value)['interactions'], isEmpty);
  });

  test('Disabled routes are excluded', () {
    final value = canonical();
    value['navigation'][0]['enabled'] = false;

    final result = adaptCanonicalPreview(value);

    expect(result['routes'], isEmpty);
    expect(result['interactions'], isEmpty);
  });
}
