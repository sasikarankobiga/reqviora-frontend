import 'package:flutter/material.dart';
import '../../../../app/router/route_paths.dart';

class ProjectOverviewPage extends StatelessWidget {
  const ProjectOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Overview'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Project Overview',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  RoutePaths.inputStudio,
                );
              },
              child: const Text('Open Input Studio'),
            ),
          ],
        ),
      ),
    );
  }
}
