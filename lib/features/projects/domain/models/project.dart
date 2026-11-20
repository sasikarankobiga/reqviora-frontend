// Typed project identity and response model.
//
// This is a frontend representation of the confirmed ProjectResponseDto.
// It does not make HTTP requests.

final class ProjectId {
  const ProjectId._(this.value);

  static final RegExp _guidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  factory ProjectId.parse(String value) {
    if (!_guidPattern.hasMatch(value)) {
      throw FormatException('Invalid project GUID: $value');
    }

    return ProjectId._(value.toLowerCase());
  }

  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is ProjectId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.createdAt,
    required this.lastModifiedAt,
  });

  final ProjectId id;
  final String name;
  final String description;
  final String ownerId;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;

  factory Project.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];

      if (value is! String) {
        throw FormatException('Expected string for "$key".');
      }

      return value;
    }

    final modifiedValue = json['lastModifiedAt'];

    if (modifiedValue != null && modifiedValue is! String) {
      throw const FormatException(
        'Expected string or null for "lastModifiedAt".',
      );
    }

    return Project(
      id: ProjectId.parse(requiredString('id')),
      name: requiredString('name'),
      description: requiredString('description'),
      ownerId: requiredString('ownerId'),
      createdAt: DateTime.parse(
        requiredString('createdAt'),
      ).toUtc(),
      lastModifiedAt:
          modifiedValue == null ? null : DateTime.parse(modifiedValue).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.value,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toUtc().toIso8601String(),
    };
  }
}
