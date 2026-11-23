import '../models/builder_component.dart';

class ComponentDefinition {
  final ComponentType type;
  final String displayName;
  final Map<String, dynamic> defaultProperties;

  const ComponentDefinition({
    required this.type,
    required this.displayName,
    required this.defaultProperties,
  });
}

class ComponentRegistry {
  // Component types used by the original V4 Components Studio.
  static const List<String> v4ComponentTypes = [
    'text',
    'button',
    'input',
    'card',
    'dialog',
    'tabs',
    'chart',
    'list',
    'table',
    'section',
    'container',
    'header',
    'image',
  ];

  static bool isSupportedV4Type(String type) {
    return v4ComponentTypes.contains(type);
  }

  static const Map<ComponentType, ComponentDefinition> definitions = {
    ComponentType.text: ComponentDefinition(
      type: ComponentType.text,
      displayName: 'Text',
      defaultProperties: {
        'content': 'Text',
        'fontSize': 16,
      },
    ),
    ComponentType.button: ComponentDefinition(
      type: ComponentType.button,
      displayName: 'Button',
      defaultProperties: {
        'label': 'Button',
        'enabled': true,
      },
    ),
    ComponentType.textField: ComponentDefinition(
      type: ComponentType.textField,
      displayName: 'Text Field',
      defaultProperties: {
        'placeholder': 'Enter text',
        'required': false,
      },
    ),
    ComponentType.card: ComponentDefinition(
      type: ComponentType.card,
      displayName: 'Card',
      defaultProperties: {
        'padding': 16,
        'elevation': 1,
      },
    ),
  };

  static ComponentDefinition getDefinition(ComponentType type) {
    return definitions[type]!;
  }

  static BuilderComponent createComponent({
    required String id,
    required ComponentType type,
  }) {
    final definition = getDefinition(type);

    return BuilderComponent(
      id: id,
      type: type,
      properties: Map<String, dynamic>.from(
        definition.defaultProperties,
      ),
    );
  }

  static bool validateProperties(BuilderComponent component) {
    final defaults = getDefinition(component.type).defaultProperties;

    for (final entry in component.properties.entries) {
      if (!defaults.containsKey(entry.key)) {
        return false;
      }

      final expectedValue = defaults[entry.key];

      if (entry.value.runtimeType != expectedValue.runtimeType) {
        return false;
      }

      // Reject blank text values for labels and placeholders.
      if (entry.key == 'label' || entry.key == 'placeholder') {
        if (entry.value is! String || (entry.value as String).trim().isEmpty) {
          return false;
        }
      }

      // Text font size must be within a reasonable range.
      if (entry.key == 'fontSize') {
        final size = entry.value as int;
        if (size < 8 || size > 96) {
          return false;
        }
      }

      // Card padding and elevation cannot be negative.
      if (entry.key == 'padding' || entry.key == 'elevation') {
        final value = entry.value as int;
        if (value < 0 || value > 100) {
          return false;
        }
      }
    }

    return true;
  }
}
