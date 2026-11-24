enum ComponentType {
  text,
  button,
  textField,
  card,
}

class BuilderComponent {
  final String id;
  final ComponentType type;
  final Map<String, dynamic> properties;

  const BuilderComponent({
    required this.id,
    required this.type,
    this.properties = const {},
  });

  BuilderComponent copyWith({
    String? id,
    ComponentType? type,
    Map<String, dynamic>? properties,
  }) {
    return BuilderComponent(
      id: id ?? this.id,
      type: type ?? this.type,
      properties: properties ?? this.properties,
    );
  }
}
