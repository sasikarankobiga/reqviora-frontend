import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/models/builder_component.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/component_registry.dart';

void main() {
  group('ComponentRegistry', () {
    test('contains all supported component types', () {
      expect(ComponentRegistry.definitions.length, 4);

      for (final type in ComponentType.values) {
        expect(ComponentRegistry.definitions.containsKey(type), true);
      }
    });

    test('creates a button with default properties', () {
      final component = ComponentRegistry.createComponent(
        id: 'CMP-002',
        type: ComponentType.button,
      );

      expect(component.properties['label'], 'Button');
      expect(component.properties['enabled'], true);
    });

    test('accepts valid properties', () {
      const component = BuilderComponent(
        id: 'CMP-003',
        type: ComponentType.text,
        properties: {'content': 'Hello', 'fontSize': 18},
      );

      expect(ComponentRegistry.validateProperties(component), true);
    });

    test('rejects unsupported properties', () {
      const component = BuilderComponent(
        id: 'CMP-004',
        type: ComponentType.button,
        properties: {'unknownProperty': 'invalid'},
      );

      expect(ComponentRegistry.validateProperties(component), false);
    });

    test('rejects wrong property types', () {
      const component = BuilderComponent(
        id: 'CMP-005',
        type: ComponentType.button,
        properties: {'enabled': 'yes'},
      );

      expect(ComponentRegistry.validateProperties(component), false);
    });
  });
}
