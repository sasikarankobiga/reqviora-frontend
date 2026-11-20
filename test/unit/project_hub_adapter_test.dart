import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/data/repositories/mock_project_repository.dart';
import 'package:reqviora_frontend/features/projects/presentation/providers/project_hub_adapter.dart';
import 'package:reqviora_frontend/features/projects/presentation/view_data/project_hub_view_data.dart';

void main() {
  test('Adapter keeps unknown backend progress unknown', () async {
    final project = (await MockProjectRepository().listProjects()).first;
    final draft = ProjectHubAdapter.fromProject(project);

    expect(draft.id, project.id);
    expect(draft.name, project.name);
    expect(draft.description, project.description);
    expect(draft.phase, isNull);
    expect(draft.isCompleted, isNull);
    expect(draft.progressLabel, 'Progress not confirmed');
    expect(draft.lastActivityAt, project.createdAt);
  });

  test('Adapter requires explicit display metadata', () async {
    final project = (await MockProjectRepository().listProjects()).first;
    final draft = ProjectHubAdapter.fromProject(project);

    final display = draft.toViewData(
      approvedDisplayPhase: HubProjectPhase.requirements,
      approvedCompletionStatus: false,
    );

    expect(display.id, project.id.value);
    expect(display.updatedLabel, 'Progress not confirmed');
    expect(display.phase, HubProjectPhase.requirements);
    expect(display.isCompleted, isFalse);
  });

  test('Adapter maps list and parses typed callback ID', () async {
    final projects = await MockProjectRepository().listProjects();
    final drafts = ProjectHubAdapter.fromProjects(projects);

    expect(drafts, hasLength(2));
    expect(
      ProjectHubAdapter.parseCallbackId(drafts.first.id.value),
      projects.first.id,
    );
    expect(
      () => ProjectHubAdapter.parseCallbackId('sample-01'),
      throwsFormatException,
    );
    expect(() => drafts.clear(), throwsUnsupportedError);
  });

  test('Adapter uses modified timestamp when available', () async {
    final project = (await MockProjectRepository().listProjects()).last;
    final draft = ProjectHubAdapter.fromProject(project);

    expect(draft.lastActivityAt, project.lastModifiedAt);
  });
}
