import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/data/http_projects_repository.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';
import 'package:reqviora_frontend/features/projects/domain/projects_repository.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/projects/presentation/project_overview_page.dart';
import 'package:reqviora_frontend/features/projects/presentation/projects_page.dart';

const projectId = '87d7a096-af02-4ec3-98ae-51f313a02111';

Map<String, Object?> project({
  String name = 'Finance Portal',
  String industry = 'Financial Services',
}) => {
  'id': projectId,
  'name': name,
  'description': 'Existing description',
  'ownerId': '8bcdd3d4-40f9-4f26-8078-f4ab58122111',
  'createdAt': '2026-11-28T01:00:00Z',
  'lastModifiedAt': '2026-11-28T02:00:00Z',
  'industry': industry,
  'targetAudience': 'Existing audience',
  'projectType': 'Web application',
  'primaryPlatform': 'web',
  'technologyPreferences': 'Flutter',
  'constraints': 'Accessibility',
  'integrations': 'PayHere',
};

class _ProjectsRepository implements ProjectsRepository {
  String? updatedName;

  @override
  Future<List<ProjectSummary>> list() async => [
    ProjectSummary.fromJson(project()),
    ProjectSummary.fromJson(
      project(name: 'Clinic App', industry: 'Healthcare'),
    ),
  ];

  @override
  Future<ProjectDraft> draft(String projectId) async => ProjectDraft(
    projectId: projectId,
    version: 1,
    name: 'Finance Portal',
    description: 'Existing description',
    category: 'Financial Services',
    targets: const ['web'],
    identity: const {},
  );

  @override
  Future<ProjectSummary> update({
    required String projectId,
    required String name,
    required String description,
    required String category,
  }) async {
    updatedName = name;
    return ProjectSummary.fromJson(project(name: name, industry: category));
  }

  @override
  Future<ProjectSummary> create({
    required String name,
    required String description,
    required String category,
    required List<String> designTargets,
  }) => throw UnimplementedError();

  @override
  Future<ProjectDraft> saveIdentity(
    String projectId,
    Map<String, dynamic> values,
  ) => throw UnimplementedError();
}

Widget appFor(ProjectsRepository repository, String location) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
      GoRoute(
        path: '/projects/:id/overview',
        builder:
            (_, state) =>
                ProjectOverviewPage(projectId: state.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [projectsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test(
    'project list retains backend category and filters actual results',
    () async {
      final api = ApiClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode([
              project(),
              project(name: 'Clinic App', industry: 'Healthcare'),
            ]),
            200,
          ),
        ),
      );
      addTearDown(api.dispose);

      final items = await HttpProjectsRepository(api).list();

      expect(items.first.category, 'Financial Services');
      expect(
        filterProjectSummaries(items, query: 'clinic').single.name,
        'Clinic App',
      );
      expect(
        filterProjectSummaries(
          items,
          category: 'Financial Services',
        ).single.name,
        'Finance Portal',
      );
    },
  );

  test(
    'project edit preserves backend fields the editor does not expose',
    () async {
      var putCount = 0;
      final api = ApiClient(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(jsonEncode(project()), 200);
          }
          expect(request.method, 'PUT');
          expect(request.url.path, '/api/projects/$projectId');
          putCount++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['name'], 'Updated portal');
          expect(body['description'], 'Updated description');
          expect(body['industry'], 'Software / SaaS');
          expect(body['targetAudience'], 'Existing audience');
          expect(body['projectType'], 'Web application');
          expect(body['primaryPlatform'], 'web');
          expect(body['technologyPreferences'], 'Flutter');
          expect(body['constraints'], 'Accessibility');
          expect(body['integrations'], 'PayHere');
          return http.Response(
            jsonEncode(
              project(name: 'Updated portal', industry: 'Software / SaaS'),
            ),
            200,
          );
        }),
      );
      addTearDown(api.dispose);

      final result = await HttpProjectsRepository(api).update(
        projectId: projectId,
        name: ' Updated portal ',
        description: ' Updated description ',
        category: ' Software / SaaS ',
      );

      expect(putCount, 1);
      expect(result.name, 'Updated portal');
      expect(result.category, 'Software / SaaS');
    },
  );

  testWidgets('project directory search filters real backend items', (
    tester,
  ) async {
    await tester.pumpWidget(appFor(_ProjectsRepository(), '/projects'));
    await tester.pumpAndSettle();

    expect(find.text('Finance Portal'), findsOneWidget);
    expect(find.text('Clinic App'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('project-search')),
      'clinic',
    );
    await tester.pump();

    expect(find.text('Finance Portal'), findsNothing);
    expect(find.text('Clinic App'), findsOneWidget);
  });

  testWidgets('project overview edits through the repository contract', (
    tester,
  ) async {
    final repository = _ProjectsRepository();
    await tester.pumpWidget(
      appFor(repository, '/projects/$projectId/overview'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-project')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-project-name')),
      'Updated portal',
    );
    await tester.tap(find.byKey(const ValueKey('save-project-edit')));
    await tester.pumpAndSettle();

    expect(repository.updatedName, 'Updated portal');
  });
}
