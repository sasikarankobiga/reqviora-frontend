
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../providers/project_overview_provider.dart';

class ProjectOverviewPage extends ConsumerWidget {
  final String projectId;

  const ProjectOverviewPage({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Project Overview'),
        leading: IconButton(
          tooltip: 'Back to Dashboard',
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: authState.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => _MessageView(
            title: 'Authentication unavailable',
            message: 'Please sign in again.',
            onPressed: () => context.go('/login'),
            buttonLabel: 'Sign In',
          ),
          data: (session) {
            if (session == null || session.isAccessTokenExpired) {
              return _MessageView(
                title: 'Sign in required',
                message:
                    'Please sign in to view project details.',
                onPressed: () => context.go('/login'),
                buttonLabel: 'Sign In',
              );
            }

            return _ProjectOverviewContent(projectId: projectId);
          },
        ),
      ),
    );
  }
}

class _ProjectOverviewContent extends ConsumerWidget {
  final String projectId;

  const _ProjectOverviewContent({
    required this.projectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewState = ref.watch(
      projectOverviewProvider(projectId),
    );

    return overviewState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => _MessageView(
        title: 'Unable to load project overview',
        message: 'Check your connection and try again.',
        buttonLabel: 'Retry',
        onPressed: () {
          ref.invalidate(projectOverviewProvider(projectId));
        },
      ),
      data: (overview) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overview.name,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        overview.description.isEmpty
                            ? 'No description provided.'
                            : overview.description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _OverviewStatCard(
                            label: 'Requirements',
                            count: overview.requirementCount,
                            icon: Icons.fact_check_outlined,
                          ),
                          _OverviewStatCard(
                            label: 'Features',
                            count: overview.featureCount,
                            icon: Icons.widgets_outlined,
                          ),
                          _OverviewStatCard(
                            label: 'Screens',
                            count: overview.screenCount,
                            icon: Icons.web_outlined,
                          ),
                          _OverviewStatCard(
                            label: 'Navigation',
                            count: overview.navigationCount,
                            icon: Icons.route_outlined,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Design Progress',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                overview.currentDraftVersion == null
                                    ? 'No design draft created yet.'
                                    : 'Current Draft Version: '
                                        '${overview.currentDraftVersion}',
                              ),
                              const SizedBox(height: 12),
                              Text(
                                overview.approvedRevisionId == null
                                    ? 'Approval: Not approved'
                                    : 'Approval: Approved revision available',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: () => context.go('/dashboard'),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Dashboard'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;

  const _OverviewStatCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.primary, size: 30),
              const SizedBox(height: 16),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _MessageView({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              size: 56,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
