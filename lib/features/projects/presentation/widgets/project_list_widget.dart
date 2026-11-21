
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/project_provider.dart';

class ProjectListWidget extends ConsumerWidget {
  const ProjectListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => _MessageView(
        icon: Icons.error_outline,
        title: 'Authentication unavailable',
        message: 'Please sign in again to view your projects.',
        actionLabel: 'Sign In',
        onAction: () => context.go('/login'),
      ),
      data: (session) {
        if (session == null) {
          return _MessageView(
            icon: Icons.lock_outline,
            title: 'Sign in to view projects',
            message:
                'Your projects will appear here after you sign in.',
            actionLabel: 'Sign In',
            onAction: () => context.go('/login'),
          );
        }

        if (session.isAccessTokenExpired) {
          return _MessageView(
            icon: Icons.lock_clock_outlined,
            title: 'Session expired',
            message:
                'Please sign in again to access your projects.',
            actionLabel: 'Sign In',
            onAction: () => context.go('/login'),
          );
        }

        return const _AuthenticatedProjectList();
      },
    );
  }
}

class _AuthenticatedProjectList extends ConsumerWidget {
  const _AuthenticatedProjectList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectListProvider);

    return projectsState.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your projects...'),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => _MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load projects',
        message: 'Please check your connection and try again.',
        actionLabel: 'Retry',
        onAction: () {
          ref.invalidate(projectListProvider);
        },
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return _MessageView(
            icon: Icons.folder_open_outlined,
            title: 'No projects yet',
            message:
                'Create your first project to begin your '
                'REQVIORA journey.',
            actionLabel: 'New Project',
            onAction: () => context.go('/projects/create'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${projects.length} project(s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('refresh_projects_button'),
                  tooltip: 'Refresh Projects',
                  onPressed: () {
                    ref.invalidate(projectListProvider);
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Display projects from the backend API.
            ...projects.map(
              (project) => Card(
                key: ValueKey(project.id),
                child: ListTile(
                  // NEW: Open selected project overview.
                  onTap: () {
                    context.go(
                      '/projects/${Uri.encodeComponent(project.id)}',
                    );
                  },

                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppTheme.primary,
                  ),

                  title: Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      project.description.isEmpty
                          ? 'No description provided'
                          : project.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  trailing: const Icon(
                    Icons.folder_open_outlined,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: AppTheme.primary,
            ),

            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 20),

            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
