import 'package:flutter/material.dart';

import '../../features/projects/domain/models/project_draft.dart';
import '../../features/projects/presentation/pages/dashboard_page.dart';
import '../../features/projects/presentation/pages/create_project_page.dart';
import '../../features/projects/presentation/pages/project_overview_page.dart';
import '../../features/projects/presentation/pages/input_studio_page.dart';
import '../../features/wizard/presentation/pages/builder_step1_page.dart';

import 'route_paths.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      case RoutePaths.dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardPage(),
          settings: settings,
        );

      case RoutePaths.createProject:
        return MaterialPageRoute(
          builder: (_) => const CreateProjectPage(),
          settings: settings,
        );

      case RoutePaths.projectOverview:
        final draft = settings.arguments;

        if (draft is! ProjectDraft) {
          return _missingDraft(settings);
        }

        return MaterialPageRoute(
          builder: (_) => ProjectOverviewPage(
            projectDraft: draft,
          ),
          settings: settings,
        );

      case RoutePaths.inputStudio:
        final draft = settings.arguments;

        if (draft is! ProjectDraft) {
          return _missingDraft(settings);
        }

        return MaterialPageRoute(
          builder: (_) => InputStudioPage(
            projectDraft: draft,
          ),
          settings: settings,
        );

      case RoutePaths.builderStep1:
        final draft = settings.arguments;

        if (draft is! ProjectDraft) {
          return _missingDraft(settings);
        }

        return MaterialPageRoute(
          builder: (_) => BuilderStep1Page(
            projectDraft: draft,
          ),
          settings: settings,
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('404 - Page Not Found'),
            ),
          ),
          settings: settings,
        );
    }
  }

  static Route<dynamic> _missingDraft(
    RouteSettings settings,
  ) {
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(
          child: Text(
            'Project details are required. '
            'Please start from Create Project.',
          ),
        ),
      ),
      settings: settings,
    );
  }
}
