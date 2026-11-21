import 'package:flutter/material.dart';

import '../../features/projects/domain/models/project_requests.dart';
import '../../features/projects/presentation/pages/dashboard_page.dart';
import '../../features/projects/presentation/pages/create_project_page.dart';
import '../../features/projects/presentation/pages/project_overview_page.dart';
import '../../features/projects/presentation/pages/input_studio_page.dart';

import 'route_paths.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
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
        final arguments = settings.arguments;

        if (arguments is! CreateProjectRequest) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                child: Text('Project details are required'),
              ),
            ),
            settings: settings,
          );
        }

        return MaterialPageRoute(
          builder: (_) => ProjectOverviewPage(
            projectRequest: arguments,
          ),
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
