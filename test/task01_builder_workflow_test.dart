import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reqviora_frontend/features/builder/presentation/builder_page.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/projects/data/project_members_repository.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';
import 'package:reqviora_frontend/features/projects/domain/projects_repository.dart';
import 'package:reqviora_frontend/features/projects/presentation/create_project_page.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_overview_page.dart';
import 'package:reqviora_frontend/features/workspace/application/workspace_providers.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

class WorkflowRepository implements ProjectsRepository {
  int version = 0;
  int saves = 0;
  String name = 'Coffee Shop';
  String description = '';
  String category = 'Software / SaaS';
  Map<String, dynamic> identity = {};

  @override
  Future<List<ProjectSummary>> list() async => [];

  @override
  Future<ProjectSummary> create({
    required String name,
    required String description,
    required String category,
    required List<String> designTargets,
  }) async {
    this.name = name;
    this.description = description;
    this.category = category;

    return ProjectSummary(
      id: 'project-1',
      name: name,
      status: 'active',
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<ProjectDraft> draft(String projectId) async {
    return ProjectDraft(
      projectId: projectId,
      version: version,
      name: identity['name']?.toString() ?? name,
      description: identity['description']?.toString() ?? description,
      category: identity['category']?.toString() ?? category,
      targets: ['web'],
      identity: Map<String, dynamic>.from(identity),
    );
  }

  @override
  Future<ProjectDraft> saveIdentity(
    String projectId,
    Map<String, dynamic> values,
  ) async {
    if (values['expectedVersion'] != version) {
      throw StateError('Stale draft version');
    }

    saves++;
    version++;
    identity = Map<String, dynamic>.from(values)..remove('expectedVersion');

    return draft(projectId);
  }
}

void main() {
  testWidgets('Create Project to Step 02 saves Step 01 identity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = WorkflowRepository();

    final router = GoRouter(
      initialLocation: '/projects/new',
      routes: [
        GoRoute(
          path: '/projects/new',
          builder: (_, _) => const CreateProjectPage(),
        ),
        GoRoute(
          path: '/projects',
          builder: (_, _) => const Scaffold(body: Text('Projects')),
        ),
        GoRoute(
          path: '/projects/:id/overview',
          builder:
              (_, state) =>
                  ProjectOverviewPage(projectId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/projects/:id/builder/:step',
          builder:
              (_, state) => BuilderPage(
                projectId: state.pathParameters['id']!,
                step: int.parse(state.pathParameters['step']!),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsRepositoryProvider.overrideWithValue(repo),
          builderMemberRoleProvider(
            'project-1',
          ).overrideWith((ref) async => ProjectMemberRole.owner),
          workspaceProvider('project-1').overrideWith(
            (ref) async => const Workspace(
              projectId: 'project-1',
              draftId: 'draft-project-1',
              version: 0,
              projectName: 'Coffee Shop',
              designTargets: ['web'],
              sections: <String, dynamic>{},
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('create-project-name')),
      'Coffee Shop',
    );

    final create = find.byKey(const ValueKey('create-project-submit'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/projects/project-1/overview',
    );

    router.go('/projects/project-1/builder/1');
    await tester.pumpAndSettle();

    expect(find.byType(IdentityEditor), findsOneWidget);
    expect(find.text('Identity & Audience'), findsWidgets);

    final save = find.text('Save & Continue');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.saves, 1);
    expect(repo.version, 1);
    expect(repo.identity['name'], 'Coffee Shop');

    expect(
      router.routeInformationProvider.value.uri.path,
      '/projects/project-1/builder/2',
    );

    expect(tester.takeException(), isNull);
  });
}
