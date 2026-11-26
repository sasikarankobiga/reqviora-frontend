import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';
import 'package:reqviora_frontend/features/projects/domain/projects_repository.dart';

class _CountingProjectsRepository implements ProjectsRepository {
  int listCalls = 0;

  @override
  Future<List<ProjectSummary>> list() async {
    listCalls++;
    return [
      ProjectSummary(
        id: 'project-$listCalls',
        name: 'Project $listCalls',
        status: 'active',
        updatedAt: DateTime.utc(2026),
      ),
    ];
  }

  @override
  Future<ProjectSummary> create({
    required String name,
    required String description,
    required String category,
    required List<String> designTargets,
  }) => throw UnimplementedError();

  @override
  Future<ProjectDraft> draft(String projectId) => throw UnimplementedError();

  @override
  Future<ProjectDraft> saveIdentity(
    String projectId,
    Map<String, dynamic> values,
  ) => throw UnimplementedError();
}

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  test('session generation changes for login and logout but not refresh', () {
    final initial = authSession.generation;
    authSession.startSession(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      accessExpiresAt: DateTime.utc(2027),
    );
    final signedIn = authSession.generation;
    expect(signedIn, initial + 1);

    expect(
      authSession.refreshSession(
        expectedGeneration: signedIn,
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
        accessExpiresAt: DateTime.utc(2027, 2),
      ),
      isTrue,
    );
    expect(authSession.generation, signedIn);

    authSession.signOut();
    expect(authSession.generation, signedIn + 1);
  });

  test(
    'project cache is discarded when the authenticated account changes',
    () async {
      final repository = _CountingProjectsRepository();
      final container = ProviderContainer(
        overrides: [projectsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      authSession.signIn('account-a');
      expect(
        (await container.read(projectsProvider.future)).single.id,
        'project-1',
      );

      authSession.signOut();
      authSession.signIn('account-b');
      await Future<void>.delayed(Duration.zero);

      expect(
        (await container.read(projectsProvider.future)).single.id,
        'project-2',
      );
      expect(repository.listCalls, 2);
    },
  );
}
