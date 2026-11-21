import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/projects/domain/models/project.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project_requests.dart';

void main() {
  group('Project field validation', () {
    test('Valid project name is accepted', () {
      final request = CreateProjectRequest(
        name: '  REQVIORA  ',
        description: 'Software design workspace',
      );

      expect(request.name, 'REQVIORA');
      expect(
        request.description,
        'Software design workspace',
      );
    });

    test('Short project name is rejected', () {
      expect(
        () => CreateProjectRequest(
          name: 'A',
          description: 'Test',
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('Empty project name is rejected', () {
      expect(
        () => CreateProjectRequest(
          name: '   ',
          description: '',
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('Project name over 200 characters is rejected', () {
      expect(
        () => CreateProjectRequest(
          name: 'A' * 201,
          description: '',
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('Description over 4000 characters is rejected', () {
      expect(
        () => CreateProjectRequest(
          name: 'REQVIORA',
          description: 'A' * 4001,
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('Create request maps to backend JSON', () {
      final request = CreateProjectRequest(
        name: 'REQVIORA',
        description: 'Design workspace',
      );

      expect(request.toJson(), {
        'name': 'REQVIORA',
        'description': 'Design workspace',
      });
    });

    test('Update request uses same validation', () {
      final request = UpdateProjectRequest(
        name: 'Updated Project',
        description: 'Updated description',
      );

      expect(request.toJson()['name'], 'Updated Project');
    });
  });

  group('Project identity', () {
    test('Valid GUID is accepted', () {
      final id = ProjectId.parse(
        '550e8400-e29b-41d4-a716-446655440000',
      );

      expect(
        id.value,
        '550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('Invalid GUID is rejected', () {
      expect(
        () => ProjectId.parse('invalid-id'),
        throwsFormatException,
      );
    });
  });
}
