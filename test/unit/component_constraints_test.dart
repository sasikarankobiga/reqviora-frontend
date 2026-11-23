import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/models/builder_component.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/component_registry.dart';

void main() {
  group('Component Registry Constraints', () {
    test('rejects empty button label', () {
      const component = BuilderComponent(
        id: 'CMP-101',
        type: ComponentType.button,
        properties: {'label': '   '},
      );

      expect(ComponentRegistry.validateProperties(component), false);
    });

    test('rejects negative font size', () {
      const component = BuilderComponent(
        id: 'CMP-102',
        type: ComponentType.text,
        properties: {'fontSize': -5},
      );

      expect(ComponentRegistry.validateProperties(component), false);
    });

    test('rejects excessive font size', () {
      const component = BuilderComponent(
        id: 'CMP-103',
        type: ComponentType.text,
        properties: {'fontSize': 120},
      );

      expect(ComponentRegistry.validateProperties(component), false);
    });

    test('rejects negative card padding', () {
      const component = BuilderComponent(
        id: 'CMP-104',
        type: ComponentType.card,
        properties: {'padding': -10},
      );

      expect(ComponentRegistry.validateProperties(component), false);
    });

    test('accepts valid card padding', () {
      const component = BuilderComponent(
        id: 'CMP-105',
        type: ComponentType.card,
        properties: {'padding': 16, 'elevation': 2},
      );

      expect(ComponentRegistry.validateProperties(component), true);
    });
  });
}
