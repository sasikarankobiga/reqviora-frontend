import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/models/builder_component.dart';

void main() {
  group('BuilderComponent', () {
    test('creates a button component', () {
      const component = BuilderComponent(
        id: 'CMP-001',
        type: ComponentType.button,
        properties: {'label': 'Save'},
      );

      expect(component.id, 'CMP-001');
      expect(component.type, ComponentType.button);
      expect(component.properties['label'], 'Save');
    });

    test('copyWith updates properties', () {
      const original = BuilderComponent(
        id: 'CMP-001',
        type: ComponentType.button,
        properties: {'label': 'Save'},
      );

      final updated = original.copyWith(
        properties: {'label': 'Submit'},
      );

      expect(updated.properties['label'], 'Submit');
      expect(original.properties['label'], 'Save');
    });
  });
}
