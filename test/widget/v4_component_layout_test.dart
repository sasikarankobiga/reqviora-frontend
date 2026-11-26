import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/v4_component_layout.dart';

void main() {
  Map<String, dynamic> component(
    String id,
    String type, {
    String screenId = 'screen-1',
    String? parentId,
  }) {
    return {
      'id': id,
      'type': type,
      'screenId': screenId,
      'label': id,
      if (parentId != null) 'parentComponentId': parentId,
    };
  }

  test('accepts valid nested components', () {
    final components = [
      component('root', 'container'),
      component('card-1', 'card', parentId: 'root'),
      component('text-1', 'text', parentId: 'card-1'),
    ];

    expect(V4ComponentLayout.validate(components), isNull);
  });

  test('rejects missing parent', () {
    final components = [
      component('text-1', 'text', parentId: 'missing'),
    ];

    expect(
      V4ComponentLayout.validate(components),
      contains('Missing parent'),
    );
  });

  test('rejects self parent', () {
    final components = [
      component('card-1', 'card', parentId: 'card-1'),
    ];

    expect(
      V4ComponentLayout.validate(components),
      contains('own parent'),
    );
  });

  test('rejects circular nesting', () {
    final components = [
      component('card-a', 'card', parentId: 'card-b'),
      component('card-b', 'card', parentId: 'card-a'),
    ];

    expect(
      V4ComponentLayout.validate(components),
      contains('Circular'),
    );
  });

  test('rejects unsupported parent type', () {
    final components = [
      component('button-1', 'button'),
      component('text-1', 'text', parentId: 'button-1'),
    ];

    expect(
      V4ComponentLayout.validate(components),
      contains('Parent must'),
    );
  });

  test('rejects cross-screen nesting', () {
    final components = [
      component('container-1', 'container'),
      component(
        'text-1',
        'text',
        screenId: 'screen-2',
        parentId: 'container-1',
      ),
    ];

    expect(
      V4ComponentLayout.validate(components),
      contains('same screen'),
    );
  });

  test('rejects duplicate component IDs', () {
    final components = [
      component('duplicate', 'card'),
      component('duplicate', 'text'),
    ];

    expect(
      V4ComponentLayout.validate(components),
      contains('Duplicate'),
    );
  });

  test('reuses component with new identity and preserved properties', () {
    final source = <String, dynamic>{
      'id': 'original-card',
      'screenId': 'screen-1',
      'type': 'card',
      'label': 'Profile',
      'parentComponentId': 'root',
      'properties': <String, dynamic>{
        'padding': 16,
        'elevation': 4,
      },
    };

    final clone = V4ComponentLayout.cloneForReuse(
      source: source,
      newId: 'reused-card',
      targetScreenId: 'screen-2',
    );

    expect(clone['id'], 'reused-card');
    expect(clone['screenId'], 'screen-2');
    expect(clone['templateSourceId'], 'original-card');
    expect(clone['parentComponentId'], isNull);
    expect(clone['type'], 'card');
    expect(clone['label'], 'Profile');

    final props = clone['properties'] as Map<String, dynamic>;

    expect(props['padding'], 16);
    expect(props['elevation'], 4);

    props['padding'] = 32;

    expect(
      (source['properties'] as Map)['padding'],
      16,
    );
  });

  test('rejects reuse with unchanged ID', () {
    expect(
      () => V4ComponentLayout.cloneForReuse(
        source: component('card-1', 'card'),
        newId: 'card-1',
        targetScreenId: 'screen-2',
      ),
      throwsArgumentError,
    );
  });
}
