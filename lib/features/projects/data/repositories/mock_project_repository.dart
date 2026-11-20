import '../../domain/models/project.dart';
import '../../domain/models/project_requests.dart';
import '../../domain/repositories/project_repository.dart';

/// TEST / DEVELOPMENT MOCK ONLY.
/// No HTTP, database, local storage or backend persistence.
final class MockProjectRepository implements ProjectRepository {
  MockProjectRepository({
    List<Project>? seedProjects,
    DateTime Function()? clock,
    String ownerId = defaultOwnerId,
  })  : _clock = clock ?? _fixedClock,
        _ownerId = ownerId {
    final seeds = seedProjects ?? _defaultProjects();

    for (final project in seeds) {
      if (_projects.containsKey(project.id)) {
        throw ArgumentError('Duplicate mock project ID: ${project.id}');
      }
      _projects[project.id] = project;
    }
  }

  static const String defaultOwnerId = '11111111-1111-4111-8111-111111111111';

  static const String _idPrefix = '00000000-0000-4000-8000-';

  static DateTime _fixedClock() => DateTime.utc(2026, 11, 20, 9);

  final DateTime Function() _clock;
  final String _ownerId;

  final Map<ProjectId, Project> _projects = {};
  int _nextId = 3;

  static List<Project> _defaultProjects() {
    return [
      Project(
        id: ProjectId.parse(
          '00000000-0000-4000-8000-000000000001',
        ),
        name: 'Mock Community Portal',
        description: 'Sample project for local repository testing.',
        ownerId: defaultOwnerId,
        createdAt: DateTime.utc(2026, 11, 18, 9),
        lastModifiedAt: null,
      ),
      Project(
        id: ProjectId.parse(
          '00000000-0000-4000-8000-000000000002',
        ),
        name: 'Mock Booking Workspace',
        description: 'Another in-memory demonstration project.',
        ownerId: defaultOwnerId,
        createdAt: DateTime.utc(2026, 11, 19, 10),
        lastModifiedAt: DateTime.utc(2026, 11, 19, 12),
      ),
    ];
  }

  ProjectId _nextAvailableId() {
    while (true) {
      final suffix = _nextId.toString().padLeft(12, '0');
      _nextId += 1;

      final id = ProjectId.parse('$_idPrefix$suffix');

      if (!_projects.containsKey(id)) {
        return id;
      }
    }
  }

  @override
  Future<List<Project>> listProjects() async {
    return List<Project>.unmodifiable(_projects.values);
  }

  @override
  Future<Project> getProject(ProjectId id) async {
    final project = _projects[id];

    if (project == null) {
      throw ProjectNotFoundException(id);
    }

    return project;
  }

  @override
  Future<Project> createProject({
    required String name,
    required String description,
  }) async {
    final request = CreateProjectRequest(
      name: name,
      description: description,
    );

    final project = Project(
      id: _nextAvailableId(),
      name: request.name,
      description: request.description,
      ownerId: _ownerId,
      createdAt: _clock().toUtc(),
      lastModifiedAt: null,
    );

    _projects[project.id] = project;

    return project;
  }

  @override
  Future<Project> updateProject(
    ProjectId id, {
    required String name,
    required String description,
  }) async {
    final existing = _projects[id];

    if (existing == null) {
      throw ProjectNotFoundException(id);
    }

    final request = UpdateProjectRequest(
      name: name,
      description: description,
    );

    final updated = Project(
      id: existing.id,
      name: request.name,
      description: request.description,
      ownerId: existing.ownerId,
      createdAt: existing.createdAt,
      lastModifiedAt: _clock().toUtc(),
    );

    _projects[id] = updated;

    return updated;
  }
}
