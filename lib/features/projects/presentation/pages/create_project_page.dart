import 'package:flutter/material.dart';
import '../../../../app/router/route_paths.dart';

class CreateProjectPage extends StatelessWidget {
  const CreateProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.create_new_folder_outlined,
              size: 64,
            ),
            const SizedBox(height: 20),
            const Text(
              'Create a New Project',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'Project fields will be added in Task 2.',
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  RoutePaths.projectOverview,
                );
              },
              child: const Text(
                'Continue (Navigation Demo)',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
