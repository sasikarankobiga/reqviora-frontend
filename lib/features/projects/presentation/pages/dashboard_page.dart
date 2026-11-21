import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import 'projects_hub_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProjectsHubPage(
      onCreateProject: () {
        Navigator.pushNamed(
          context,
          RoutePaths.createProject,
        );
      },
    );
  }
}
