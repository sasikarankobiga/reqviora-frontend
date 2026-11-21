import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../domain/models/project_draft.dart';

class InputStudioPage extends StatelessWidget {
  const InputStudioPage({
    super.key,
    required this.projectDraft,
  });

  final ProjectDraft projectDraft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Studio'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Input Studio',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Project: ${projectDraft.name}',
                  key: const Key('studio-project-name'),
                ),
                const SizedBox(height: 30),
                FilledButton(
                  key: const Key('open-builder-step1'),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      RoutePaths.builderStep1,
                      arguments: projectDraft,
                    );
                  },
                  child: const Text('Open Builder Step 1'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
