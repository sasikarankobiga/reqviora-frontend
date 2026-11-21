
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../projects/presentation/widgets/project_list_widget.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'REQVIORA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            return SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Workspace Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Manage your software ideas, '
                        'requirements, and design projects.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // New Project button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          key: const Key(
                            'dashboard_create_project_button',
                          ),
                          onPressed: () {
                            context.go('/projects/create');
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('New Project'),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Project statistics:
                      // Real values will be connected later.
                      const Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StatisticCard(
                            title: 'Total Projects',
                            value: '—',
                            icon: Icons.folder_outlined,
                          ),
                          _StatisticCard(
                            title: 'Active Projects',
                            value: '—',
                            icon: Icons.work_outline,
                          ),
                          _StatisticCard(
                            title: 'Completed Projects',
                            value: '—',
                            icon: Icons.check_circle_outline,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // My Projects - Riverpod Project List
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Projects',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              SizedBox(height: 8),

                              Text(
                                'Manage your software design projects.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                              ),

                              SizedBox(height: 24),

                              // Connected Project List Widget
                              ProjectListWidget(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // REQVIORA information section
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                color: AppTheme.primary,
                              ),

                              SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From Requirements to Reality',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(height: 8),

                                    Text(
                                      'REQVIORA helps transform '
                                      'software requirements into '
                                      'structured designs, screens, '
                                      'and project knowledge.',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: AppTheme.primary,
                size: 30,
              ),

              const SizedBox(height: 16),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                title,
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
