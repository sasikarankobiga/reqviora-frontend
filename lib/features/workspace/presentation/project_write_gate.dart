import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets.dart';
import '../../../core/config/app_config.dart';
import '../../projects/data/project_members_repository.dart';
import '../application/workspace_providers.dart';
import '../domain/project_edit_policy.dart';
import 'authoring_page.dart';

/// Frontend permission presentation.
/// All actual authorization remains enforced by the backend.
class ProjectWriteGate extends ConsumerWidget {
  const ProjectWriteGate({
    super.key,
    required this.projectId,
    required this.child,
    this.ownerOnly = false,
  });

  final String projectId;
  final Widget child;
  final bool ownerOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        isLocalDemo
            ? const AsyncData<ProjectMemberRole?>(ProjectMemberRole.owner)
            : ref.watch(builderMemberRoleProvider(projectId));

    return role.when(
      skipLoadingOnRefresh: false,
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => InlineError(
            'Unable to verify project permissions.',
            onRetry: () => ref.invalidate(builderMemberRoleProvider(projectId)),
          ),
      data: (memberRole) {
        if (memberRole == null) {
          return const InlineError('Project membership could not be verified.');
        }

        return ref
            .watch(workspaceProvider(projectId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, stack) => InlineError(
                    'Unable to load project permissions and draft.',
                    onRetry: () => ref.invalidate(workspaceProvider(projectId)),
                  ),
              data: (workspace) {
                final policy = ProjectEditPolicy(
                  role: memberRole,
                  approved: workspace.isApproved,
                );

                final allowed =
                    policy.canEdit &&
                    (!ownerOnly || memberRole == ProjectMemberRole.owner);

                if (allowed) return child;

                return SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LocalizedSectionTitle('Read-only workspace'),
                      const SizedBox(height: 12),
                      Text(
                        workspace.isApproved
                            ? 'Approved drafts cannot be edited.'
                            : 'Your role does not permit this editing operation.',
                      ),
                      const SizedBox(height: 12),
                      Text('Project: ${workspace.projectName}'),
                      Text('Role: ${memberRole.apiValue}'),
                      Text('Draft version: ${workspace.version}'),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed:
                            () => context.go('/projects/$projectId/overview'),
                        child: const LocalizedUiText(
                          'Back to project overview',
                        ),
                      ),
                      OutlinedButton(
                        onPressed:
                            () => context.go('/projects/$projectId/preview'),
                        child: const LocalizedUiText('Open preview'),
                      ),
                    ],
                  ),
                );
              },
            );
      },
    );
  }
}
