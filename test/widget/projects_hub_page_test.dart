import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/presentation/pages/projects_hub_page.dart';
import 'package:reqviora_frontend/features/projects/presentation/view_data/project_hub_view_data.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_theme.dart';

Widget wrap(Widget child) => MaterialApp(theme: ReqvioraTheme.light, home: child);

void main() {
  testWidgets('Empty workspace displays start message and create callback', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(ProjectsHubPage(onCreateProject: () => calls++)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hub-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hub-create-project')));
    expect(calls, 1);
  });

  testWidgets('Loading workspace displays progress', (tester) async {
    await tester.pumpWidget(wrap(const ProjectsHubPage(status: ProjectsHubStatus.loading)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('hub-loading')), findsOneWidget);
    expect(find.byKey(const Key('hub-progress-indicator')), findsOneWidget);
  });

  testWidgets('Error state exposes retry callback', (tester) async {
    var retries = 0;
    await tester.pumpWidget(wrap(ProjectsHubPage(
      status: ProjectsHubStatus.error,
      onRetry: () => retries++,
      errorMessage: 'Unable to load sample view.',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load sample view.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('hub-retry')));
    await tester.tap(find.byKey(const Key('hub-retry')));
    expect(retries, 1);
  });

  testWidgets('Project open and resume callbacks receive presentation ID', (tester) async {
    String? opened;
    String? resumed;
    await tester.pumpWidget(wrap(ProjectsHubPage(
      status: ProjectsHubStatus.populated,
      projects: ProjectsHubPreviewSamples.projects,
      onOpenProject: (id) => opened = id,
      onResumeProject: (id) => resumed = id,
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('hub-resume-project')));
    await tester.tap(find.byKey(const Key('hub-resume-project')));
    expect(resumed, 'sample-01');
    await tester.ensureVisible(find.byKey(const Key('hub-project-sample-02')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hub-project-sample-02')).last);
    expect(opened, 'sample-02');
  });

  testWidgets('Search and filter update visible projects and invoke callbacks', (tester) async {
    String? latestSearch;
    HubProjectFilter? latestFilter;
    await tester.pumpWidget(wrap(ProjectsHubPage(
      status: ProjectsHubStatus.populated,
      projects: ProjectsHubPreviewSamples.projects,
      onSearchChanged: (text) => latestSearch = text,
      onFilterChanged: (filter) => latestFilter = filter,
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('hub-project-search')));
    await tester.enterText(find.byKey(const Key('hub-project-search')), 'museum');
    await tester.pumpAndSettle();
    expect(latestSearch, 'museum');
    expect(find.byKey(const Key('hub-project-sample-04')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('hub-filter-inProgress')));
    await tester.tap(find.byKey(const Key('hub-filter-inProgress')));
    await tester.pumpAndSettle();
    expect(latestFilter, HubProjectFilter.inProgress);
    expect(find.byKey(const Key('hub-no-results')), findsOneWidget);
  });

  for (final (width, height, key) in [
    (1440.0, 900.0, 'hub-desktop-layout'),
    (800.0, 900.0, 'hub-tablet-layout'),
    (390.0, 844.0, 'hub-mobile-layout'),
  ]) {
    testWidgets('Responsive layout $width x $height', (tester) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(wrap(const ProjectsHubPage(
        status: ProjectsHubStatus.populated,
        projects: ProjectsHubPreviewSamples.projects,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(Key(key)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
