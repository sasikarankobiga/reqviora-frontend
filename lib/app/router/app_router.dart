import 'package:flutter/material.dart';

import '../../features/projects/presentation/pages/dashboard_page.dart';
import '../../features/projects/presentation/pages/create_project_page.dart';
import '../../features/projects/presentation/pages/project_overview_page.dart';
import '../../features/projects/presentation/pages/input_studio_page.dart';

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
        return MaterialPageRoute(
          builder: (_) => const ProjectOverviewPage(),
          settings: settings,
        );

      case RoutePaths.inputStudio:
        return MaterialPageRoute(
          builder: (_) => const InputStudioPage(),
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
}
