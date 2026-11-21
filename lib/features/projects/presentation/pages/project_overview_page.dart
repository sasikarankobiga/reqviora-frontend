import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../domain/models/project_requests.dart';

class ProjectOverviewPage extends StatelessWidget {
  const ProjectOverviewPage({
    super.key,
    required this.projectRequest,
  });

  final CreateProjectRequest projectRequest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Overview'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Project Overview',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Project Name',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  projectRequest.name,
                  key: const Key('overview-project-name'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Project Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  projectRequest.description.isEmpty
                      ? 'Not provided'
                      : projectRequest.description,
                  key: const Key('overview-project-description'),
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      RoutePaths.inputStudio,
                      arguments: projectRequest,
                    );
                  },
                  child: const Text('Open Input Studio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
