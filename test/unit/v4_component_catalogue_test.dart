import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/component_registry.dart';

void main() {
  v4ComponentIdSafetyTests();
  v4ScreenReferenceTests();
  v4ComponentValidationTests();
  group('Original V4 Component Catalogue', () {
    test('contains all 13 original V4 types', () {
      expect(ComponentRegistry.v4ComponentTypes.length, 13);
      expect(
        ComponentRegistry.v4ComponentTypes.toSet().length,
        13,
      );
    });

    test('supports existing V4 component types', () {
      expect(ComponentRegistry.isSupportedV4Type('button'), true);
      expect(ComponentRegistry.isSupportedV4Type('input'), true);
      expect(ComponentRegistry.isSupportedV4Type('dialog'), true);
      expect(ComponentRegistry.isSupportedV4Type('image'), true);
    });

    test('rejects unknown component type', () {
      expect(ComponentRegistry.isSupportedV4Type('unknown'), false);
    });
  });
}

void v4ComponentValidationTests() {
  group('V4 Component Validation', () {
    test('accepts valid component', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'button',
          label: 'Submit',
          screenId: 'screen-1',
        ),
        isNull,
      );
    });

    test('rejects unsupported type', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'unknown',
          label: 'Submit',
          screenId: 'screen-1',
        ),
        isNotNull,
      );
    });

    test('rejects empty label', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'button',
          label: '   ',
          screenId: 'screen-1',
        ),
        isNotNull,
      );
    });

    test('rejects missing screen', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'button',
          label: 'Submit',
          screenId: null,
        ),
        isNotNull,
      );
    });
  });
}

void v4ScreenReferenceTests() {
  group('V4 Screen Reference Validation', () {
    test('accepts existing screen', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'button',
          label: 'Submit',
          screenId: 'screen-1',
          validScreenIds: ['screen-1', 'screen-2'],
        ),
        isNull,
      );
    });

    test('rejects deleted screen', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'button',
          label: 'Submit',
          screenId: 'deleted-screen',
          validScreenIds: ['screen-1'],
        ),
        'Selected screen does not exist',
      );
    });

    test('rejects screen when list is empty', () {
      expect(
        ComponentRegistry.validateV4Component(
          type: 'text',
          label: 'Heading',
          screenId: 'screen-1',
          validScreenIds: [],
        ),
        isNotNull,
      );
    });
  });
}

void v4ComponentIdSafetyTests() {
  group('V4 Component ID Safety', () {
    test('accepts a unique new ID', () {
      expect(
        ComponentRegistry.validateV4ComponentId(
          id: 'component-2',
          existingIds: ['component-1'],
        ),
        isNull,
      );
    });

    test('rejects duplicate ID', () {
      expect(
        ComponentRegistry.validateV4ComponentId(
          id: 'component-1',
          existingIds: ['component-1'],
        ),
        'Duplicate component ID',
      );
    });

    test('rejects empty ID', () {
      expect(
        ComponentRegistry.validateV4ComponentId(
          id: '   ',
          existingIds: [],
        ),
        'Component ID is required',
      );
    });

    test('preserves original ID when editing', () {
      expect(
        ComponentRegistry.validateV4ComponentId(
          id: 'component-1',
          existingIds: ['component-1'],
          editingId: 'component-1',
        ),
        isNull,
      );

      expect(
        ComponentRegistry.validateV4ComponentId(
          id: 'component-2',
          existingIds: ['component-1'],
          editingId: 'component-1',
        ),
        'Component ID cannot change during editing',
      );
    });
  });
}
