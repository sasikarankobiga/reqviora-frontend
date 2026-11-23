import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/builder/domain/registry/component_registry.dart';

void main() {
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
