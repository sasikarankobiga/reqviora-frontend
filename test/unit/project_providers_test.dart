import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/data/repositories/mock_project_repository.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project_requests.dart';
import 'package:reqviora_frontend/features/projects/domain/repositories/project_repository.dart';
import 'package:reqviora_frontend/features/projects/presentation/providers/project_providers.dart';

final class ControlledProjectRepository implements ProjectRepository {
  ControlledProjectRepository({List<Project>? seeds})
      : backing = MockProjectRepository(seedProjects: seeds);

  final MockProjectRepository backing;
  Completer<List<Project>>? listGate;
  Object? listFailure;
  bool failCreate = false;
  bool failUpdate = false;
  int listCalls = 0;
  int detailCalls = 0;

  @override
  Future<List<Project>> listProjects() async {
    listCalls++;
    if (listGate case final gate?) {
      return gate.future;
    }
    if (listFailure case final error?) {
      throw error;
    }
    return backing.listProjects();
  }

  @override
  Future<Project> getProject(ProjectId id) {
    detailCalls++;
    return backing.getProject(id);
  }

  @override
  Future<Project> createProject({
    required String name,
    required String description,
  }) {
    if (failCreate) {
      return Future.error(StateError('Create failed'));
    }
    return backing.createProject(name: name, description: description);
  }

  @override
  Future<Project> updateProject(
    ProjectId id, {
    required String name,
    required String description,
  }) {
    if (failUpdate) {
      return Future.error(StateError('Update failed'));
    }
    return backing.updateProject(
      id,
      name: name,
      description: description,
    );
  }
}

void main() {
  ProviderContainer createContainer(ProjectRepository repository) {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        projectRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('Mock repository provider can be overridden', () {
    final repo = ControlledProjectRepository();
    final container = createContainer(repo);

    expect(container.read(projectRepositoryProvider), same(repo));
  });

  test('Project list starts loading and resolves to data', () async {
    final repo = ControlledProjectRepository();
    final gate = Completer<List<Project>>();
    repo.listGate = gate;
    final container = createContainer(repo);
    final subscription = container.listen(projectListProvider, (_, __) {});
    addTearDown(subscription.close);

    expect(container.read(projectListProvider).isLoading, isTrue);
    gate.complete(await repo.backing.listProjects());

    final projects = await container.read(projectListProvider.future);
    expect(projects, hasLength(2));
    expect(container.read(projectListProvider).hasValue, isTrue);
  });

  test('Empty project list resolves without error', () async {
    final repo = ControlledProjectRepository(seeds: []);
    final container = createContainer(repo);

    final projects = await container.read(projectListProvider.future);
    expect(projects, isEmpty);
    expect(container.read(projectListProvider).hasError, isFalse);
  });

  test('Repository failure exposes error state', () async {
    final repo = ControlledProjectRepository();
    repo.listFailure = StateError('Temporary failure');
    final container = createContainer(repo);

    await expectLater(
      container.read(projectListProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(container.read(projectListProvider).hasError, isTrue);
  });

  test('Retry succeeds after repository failure', () async {
    final repo = ControlledProjectRepository();
    repo.listFailure = StateError('Offline');
    final container = createContainer(repo);
    final subscription = container.listen(projectListProvider, (_, __) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(projectListProvider.future),
      throwsA(isA<StateError>()),
    );

    repo.listFailure = null;
    container.invalidate(projectListProvider);

    final projects = await container.read(projectListProvider.future);
    expect(projects, hasLength(2));
    expect(repo.listCalls, 2);
  });

  test('Typed project details return the requested project', () async {
    final repo = ControlledProjectRepository();
    final container = createContainer(repo);
    final id = ProjectId.parse(
      '00000000-0000-4000-8000-000000000002',
    );

    final project = await container.read(projectDetailsProvider(id).future);
    expect(project.id, id);
    expect(project.name, 'Mock Booking Workspace');
  });

  test('Missing project details produce error state', () async {
    final container = createContainer(ControlledProjectRepository());
    final id = ProjectId.parse(
      '00000000-0000-4000-8000-999999999999',
    );

    final subscription = container.listen(
      projectDetailsProvider(id),
      (_, __) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(projectDetailsProvider(id).future),
      throwsA(isA<ProjectNotFoundException>()),
    );
    expect(container.read(projectDetailsProvider(id)).hasError, isTrue);
  });

  test('Create invalidates and refreshes project list', () async {
    final repo = ControlledProjectRepository();
    final container = createContainer(repo);
    final subscription = container.listen(projectListProvider, (_, __) {});
    addTearDown(subscription.close);

    expect(await container.read(projectListProvider.future), hasLength(2));

    final created = await container.read(projectActionsProvider).createProject(
          name: 'New mock project',
          description: '',
        );

    final updatedList = await container.read(projectListProvider.future);
    expect(updatedList, hasLength(3));
    expect(updatedList.any((project) => project.id == created.id), isTrue);
    expect(repo.listCalls, 2);
  });

  test('Update refreshes project list and matching detail', () async {
    final repo = ControlledProjectRepository();
    final container = createContainer(repo);
    final id = ProjectId.parse(
      '00000000-0000-4000-8000-000000000001',
    );

    final listSubscription = container.listen(projectListProvider, (_, __) {});
    final detailSubscription =
        container.listen(projectDetailsProvider(id), (_, __) {});
    addTearDown(listSubscription.close);
    addTearDown(detailSubscription.close);

    await container.read(projectListProvider.future);
    await container.read(projectDetailsProvider(id).future);

    await container.read(projectActionsProvider).updateProject(
          id,
          name: 'Updated mock project',
          description: 'Updated mock description',
        );

    final list = await container.read(projectListProvider.future);
    final detail = await container.read(projectDetailsProvider(id).future);

    expect(list.first.name, 'Updated mock project');
    expect(detail.name, 'Updated mock project');
    expect(repo.listCalls, 2);
    expect(repo.detailCalls, 2);
  });

  test('Failed create leaves existing cached list unchanged', () async {
    final repo = ControlledProjectRepository()..failCreate = true;
    final container = createContainer(repo);
    final subscription = container.listen(projectListProvider, (_, __) {});
    addTearDown(subscription.close);

    final before = await container.read(projectListProvider.future);

    await expectLater(
      container.read(projectActionsProvider).createProject(
            name: 'Valid mock name',
            description: '',
          ),
      throwsA(isA<StateError>()),
    );

    expect(container.read(projectListProvider).requireValue, same(before));
    expect(repo.listCalls, 1);
  });

  test('Failed update preserves list/details and propagates error', () async {
    final repo = ControlledProjectRepository()..failUpdate = true;
    final container = createContainer(repo);
    final id = ProjectId.parse(
      '00000000-0000-4000-8000-000000000001',
    );

    final listSub = container.listen(projectListProvider, (_, __) {});
    final detailSub = container.listen(projectDetailsProvider(id), (_, __) {});
    addTearDown(listSub.close);
    addTearDown(detailSub.close);

    final beforeList = await container.read(projectListProvider.future);
    final beforeDetail =
        await container.read(projectDetailsProvider(id).future);

    await expectLater(
      container.read(projectActionsProvider).updateProject(
            id,
            name: 'Changed name',
            description: '',
          ),
      throwsA(isA<StateError>()),
    );

    expect(
      container.read(projectListProvider).requireValue,
      same(beforeList),
    );
    expect(
      container.read(projectDetailsProvider(id)).requireValue,
      same(beforeDetail),
    );
    expect(repo.listCalls, 1);
    expect(repo.detailCalls, 1);
  });

  test('Validation exception is preserved on failed create', () async {
    final repo = ControlledProjectRepository();
    final container = createContainer(repo);

    await expectLater(
      container.read(projectActionsProvider).createProject(
            name: 'A',
            description: '',
          ),
      throwsA(isA<ProjectValidationException>()),
    );
    expect(await repo.backing.listProjects(), hasLength(2));
  });
}
