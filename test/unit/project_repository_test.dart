import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/data/repositories/mock_project_repository.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project_requests.dart';
import 'package:reqviora_frontend/features/projects/domain/repositories/project_repository.dart';

void main() {
  final fixedTime = DateTime.utc(2026, 11, 20, 10);

  MockProjectRepository repository() {
    return MockProjectRepository(clock: () => fixedTime);
  }

  group('Project models', () {
    test('ProjectId accepts a GUID and normalizes case', () {
      final id = ProjectId.parse(
        'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
      );

      expect(
        id.value,
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );

      expect(
        id,
        ProjectId.parse(
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
      );
    });

    test('ProjectId rejects an invalid ID', () {
      expect(
        () => ProjectId.parse('sample-01'),
        throwsFormatException,
      );
    });

    test('Project response parses confirmed backend fields', () {
      final project = Project.fromJson({
        'id': '00000000-0000-4000-8000-000000000010',
        'name': 'Campus Portal',
        'description': 'A sample project',
        'ownerId': MockProjectRepository.defaultOwnerId,
        'createdAt': '2026-11-19T09:00:00+05:30',
        'lastModifiedAt': null,
      });

      expect(project.name, 'Campus Portal');
      expect(project.lastModifiedAt, isNull);
      expect(
        project.createdAt,
        DateTime.utc(2026, 11, 19, 3, 30),
      );
      expect(
        project.toJson()['id'],
        '00000000-0000-4000-8000-000000000010',
      );
    });

    test('Project response rejects invalid JSON types', () {
      expect(
        () => Project.fromJson({
          'id': '00000000-0000-4000-8000-000000000010',
          'name': 123,
          'description': 'Description',
          'ownerId': MockProjectRepository.defaultOwnerId,
          'createdAt': '2026-11-19T09:00:00Z',
          'lastModifiedAt': null,
        }),
        throwsFormatException,
      );
    });

    test('Create and update requests use only confirmed fields', () {
      final create = CreateProjectRequest(
        name: '  Campus Portal  ',
        description: '  Campus events  ',
      );

      final update = UpdateProjectRequest(
        name: 'Updated Portal',
        description: '',
      );

      expect(create.toJson(), {
        'name': 'Campus Portal',
        'description': 'Campus events',
      });

      expect(update.toJson(), {
        'name': 'Updated Portal',
        'description': '',
      });
    });

    test('Request validation rejects invalid values', () {
      expect(
        () => CreateProjectRequest(
          name: 'A',
          description: '',
        ),
        throwsA(isA<ProjectValidationException>()),
      );

      expect(
        () => CreateProjectRequest(
          name: 'A' * 201,
          description: '',
        ),
        throwsA(isA<ProjectValidationException>()),
      );

      expect(
        () => UpdateProjectRequest(
          name: 'Valid Project',
          description: 'X' * 4001,
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('Boundary lengths are accepted', () {
      final request = CreateProjectRequest(
        name: 'AB',
        description: 'X' * 4000,
      );

      expect(request.name.length, 2);
      expect(request.description.length, 4000);
    });
  });

  group('MockProjectRepository', () {
    test('Lists deterministic in-memory sample projects', () async {
      final projects = await repository().listProjects();

      expect(projects, hasLength(2));
      expect(projects.first.name, 'Mock Community Portal');
      expect(
        projects.first.id.value,
        '00000000-0000-4000-8000-000000000001',
      );
      expect(projects.first.lastModifiedAt, isNull);
    });

    test('List result cannot be modified directly', () async {
      final projects = await repository().listProjects();

      expect(
        () => projects.clear(),
        throwsUnsupportedError,
      );
    });

    test('Gets an existing project by typed ID', () async {
      final repo = repository();
      final id = ProjectId.parse(
        '00000000-0000-4000-8000-000000000001',
      );

      final project = await repo.getProject(id);

      expect(project.name, 'Mock Community Portal');
    });

    test('Missing project produces typed exception', () async {
      final repo = repository();
      final missingId = ProjectId.parse(
        '00000000-0000-4000-8000-999999999999',
      );

      await expectLater(
        repo.getProject(missingId),
        throwsA(isA<ProjectNotFoundException>()),
      );
    });

    test('Creates and stores a valid project', () async {
      final repo = repository();

      final project = await repo.createProject(
        name: '  New Project  ',
        description: '  New description  ',
      );

      expect(project.name, 'New Project');
      expect(project.description, 'New description');
      expect(project.createdAt, fixedTime);
      expect(project.lastModifiedAt, isNull);

      expect(
        project.id.value,
        '00000000-0000-4000-8000-000000000003',
      );

      expect(await repo.getProject(project.id), same(project));
      expect(await repo.listProjects(), hasLength(3));
    });

    test('Rejects invalid creation without saving', () async {
      final repo = repository();

      await expectLater(
        repo.createProject(name: ' ', description: ''),
        throwsA(isA<ProjectValidationException>()),
      );

      expect(await repo.listProjects(), hasLength(2));
    });

    test('Updates supported fields and preserves identity', () async {
      final repo = repository();
      final original = (await repo.listProjects()).first;

      final updated = await repo.updateProject(
        original.id,
        name: 'Updated Community Portal',
        description: 'Updated description',
      );

      expect(updated.id, original.id);
      expect(updated.ownerId, original.ownerId);
      expect(updated.createdAt, original.createdAt);
      expect(updated.lastModifiedAt, fixedTime);
      expect(updated.name, 'Updated Community Portal');
      expect(updated.description, 'Updated description');

      expect((await repo.getProject(original.id)).name,
          'Updated Community Portal');
    });

    test('Missing project update throws exception', () async {
      final repo = repository();
      final missingId = ProjectId.parse(
        '00000000-0000-4000-8000-999999999999',
      );

      await expectLater(
        repo.updateProject(
          missingId,
          name: 'Valid Name',
          description: '',
        ),
        throwsA(isA<ProjectNotFoundException>()),
      );
    });

    test('Invalid update preserves previous project', () async {
      final repo = repository();
      final original = (await repo.listProjects()).first;

      await expectLater(
        repo.updateProject(
          original.id,
          name: 'A',
          description: '',
        ),
        throwsA(isA<ProjectValidationException>()),
      );

      expect(
        await repo.getProject(original.id),
        same(original),
      );
    });

    test('Repository instances do not share memory', () async {
      final first = repository();
      final second = repository();

      await first.createProject(
        name: 'Only First',
        description: '',
      );

      expect(await first.listProjects(), hasLength(3));
      expect(await second.listProjects(), hasLength(2));
    });
  });
}
