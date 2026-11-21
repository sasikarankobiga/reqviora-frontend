import 'package:flutter/material.dart';
import '../../../../app/router/route_paths.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REQVIORA Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.dashboard, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Welcome to REQVIORA',
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
                  RoutePaths.createProject,
                );
              },
              child: const Text('Create Project'),
            ),
          ],
        ),
      ),
    );
  }
}
