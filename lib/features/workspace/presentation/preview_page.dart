import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/widgets.dart';
import '../application/workspace_providers.dart';
import 'simulated_preview.dart';
import 'revision_history_panel.dart';

class ProjectPreviewPage extends ConsumerWidget {
  const ProjectPreviewPage({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
    pageTitle: 'Simulated Preview',
    projectId: projectId,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageIntro(
          eyebrow: 'Design / Preview',
          title: 'Test your connected design',
          subtitle:
              'All interactions are simulated locally. No customer transactions are possible.',
        ),
        const SizedBox(height: 19),
        RevisionHistoryPanel(
          key: ValueKey('revision-history-$projectId'),
          projectId: projectId,
        ),
        const SizedBox(height: 19),
        ref
            .watch(workspaceProvider(projectId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => InlineError(
                    '$e',
                    onRetry: () => ref.invalidate(workspaceProvider(projectId)),
                  ),
              data: (workspace) {
                final blueprint = workspace.fields('blueprint');
 feature/thikal-v4-frontend-development
                final visualDraft = workspace.fields('visualEditorDraft');

                final hasCanonical = blueprint['screens'] is List;
                final hasVisualDraft = visualDraft['screens'] is List;

                return hasCanonical || hasVisualDraft
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasVisualDraft) ...[
                          const LocalizedSectionTitle(
                            'Saved visual draft',
                            subtitle:
                                'Local simulation only. Not the approved Blueprint.',
                          ),
                          const SizedBox(height: 12),
                          SafePreview(
                            key: const ValueKey('saved-visual-preview'),
                            blueprint: visualDraft,
                            interactionRules: workspace.items('interactions'),
                          ),
                        ],
                        if (hasCanonical) ...[
                          const SizedBox(height: 20),
                          const LocalizedSectionTitle(
                            'Canonical Blueprint',
                            subtitle:
                                'Server-generated design. Approval is a separate action.',
                          ),
                          const SizedBox(height: 12),
                          SafePreview(
                            key: const ValueKey('canonical-preview'),
                            blueprint: blueprint,
                          ),
                        ],
                      ],
                    )

              return blueprint['screens'] is List
                    ? SafePreview(blueprint: blueprint, interactionRules: workspace.items('interactions'))
develop
                    : SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No local preview is saved yet. Open Builder Step 07 to generate one.',
                          ),
                          const SizedBox(height: 15),
                          FilledButton(
                            onPressed:
                                () => context.go(
                                  '/projects/$projectId/builder/7',
                                ),
                            child: const LocalizedUiText('Open UI Studio'),
                          ),
                        ],
                      ),
                    );
              },
            ),
      ],
    ),
  );
}
