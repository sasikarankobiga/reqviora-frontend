// Request models based on the confirmed backend CreateProjectDto
// and UpdateProjectDto. Both currently require name and description.

final class ProjectValidationException implements Exception {
  const ProjectValidationException(this.message);

  final String message;

  @override
  String toString() => 'ProjectValidationException: $message';
}

abstract final class ProjectFieldValidation {
  static String validateName(String value) {
    final name = value.trim();

    if (name.length < 2 || name.length > 200) {
      throw const ProjectValidationException(
        'Project name must contain 2 to 200 characters.',
      );
    }

    return name;
  }

  static String validateDescription(String value) {
    final description = value.trim();

    if (description.length > 4000) {
      throw const ProjectValidationException(
        'Project description cannot exceed 4000 characters.',
      );
    }

    return description;
  }
}

final class CreateProjectRequest {
  CreateProjectRequest({
    required String name,
    required String description,
  })  : name = ProjectFieldValidation.validateName(name),
        description = ProjectFieldValidation.validateDescription(description);

  final String name;
  final String description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}

final class UpdateProjectRequest {
  UpdateProjectRequest({
    required String name,
    required String description,
  })  : name = ProjectFieldValidation.validateName(name),
        description = ProjectFieldValidation.validateDescription(description);

  final String name;
  final String description;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}
