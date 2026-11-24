import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/widgets.dart';
import '../application/workspace_providers.dart';
import 'simulated_preview.dart';

class ProjectPreviewPage extends ConsumerWidget {
  const ProjectPreviewPage({super.key, required this.projectId});
  final String projectId;
  @override Widget build(BuildContext context, WidgetRef ref) => AppShell(
    pageTitle: 'Simulated Preview', projectId: projectId,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageIntro(eyebrow: 'Design / Preview', title: 'Test your connected design',
        subtitle: 'All interactions are simulated locally. No customer transactions are possible.'),
      const SizedBox(height: 19),
      ref.watch(workspaceProvider(projectId)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => InlineError('$e', onRetry: () => ref.invalidate(workspaceProvider(projectId))),
        data: (workspace) {
          final blueprint = workspace.fields('blueprint');
          return blueprint['screens'] is List ? SafePreview(blueprint: blueprint) : SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Compile your Blueprint in Builder Step 07 first.'),
              const SizedBox(height: 15), FilledButton(onPressed: () =>
                context.go('/projects/$projectId/builder/7'), child: const Text('Open UI Studio'))]));
        }),
    ]));
}
