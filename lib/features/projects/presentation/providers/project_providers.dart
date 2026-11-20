// REQVIORA TASK 005B — Riverpod project state foundation.
// Development repository is intentionally MOCK ONLY.
// No HTTP, authentication, routing or UI modifications.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../projects/data/repositories/mock_project_repository.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/domain/repositories/project_repository.dart';

/// Override this provider when testing or supplying a future API repository.
final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => MockProjectRepository(),
);

/// AsyncLoading, AsyncData(empty/populated), and AsyncError are distinct.
final projectListProvider = FutureProvider<List<Project>>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.listProjects();
});

/// Details are independently cached for each typed ProjectId.
final projectDetailsProvider = FutureProvider.family<Project, ProjectId>(
  (ref, id) {
    final repository = ref.watch(projectRepositoryProvider);
    return repository.getProject(id);
  },
);

/// Mutations use the repository. No optimistic cache updates are performed.
final projectActionsProvider = Provider<ProjectActions>((ref) {
  final repository = ref.watch(projectRepositoryProvider);

  return ProjectActions(
    repository: repository,
    onCreated: () {
      ref.invalidate(projectListProvider);
    },
    onUpdated: (id) {
      ref.invalidate(projectListProvider);
      ref.invalidate(projectDetailsProvider(id));
    },
  );
});

final class ProjectActions {
  ProjectActions({
    required ProjectRepository repository,
    required void Function() onCreated,
    required void Function(ProjectId) onUpdated,
  })  : _repository = repository,
        _onCreated = onCreated,
        _onUpdated = onUpdated;

  final ProjectRepository _repository;
  final void Function() _onCreated;
  final void Function(ProjectId) _onUpdated;

  Future<Project> createProject({
    required String name,
    required String description,
  }) async {
    final created = await _repository.createProject(
      name: name,
      description: description,
    );
    _onCreated();
    return created;
  }

  Future<Project> updateProject(
    ProjectId id, {
    required String name,
    required String description,
  }) async {
    final updated = await _repository.updateProject(
      id,
      name: name,
      description: description,
    );
    _onUpdated(id);
    return updated;
  }
}
