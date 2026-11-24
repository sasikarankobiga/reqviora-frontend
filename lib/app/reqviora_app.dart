import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/projects/presentation/create_project_page.dart';
import '../features/projects/presentation/project_overview_page.dart';
import '../features/builder/presentation/builder_page.dart';
import '../features/prebuilder/presentation/prebuilder_pages.dart';
import 'theme.dart';
import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/workspace/presentation/preview_page.dart';

final appRouter = GoRouter(
  initialLocation: '/projects',
  refreshListenable: authSession,
  redirect: (_, state) {
    if (isLocalDemo) return null;
    final login = state.matchedLocation == '/login';
    if (!authSession.authenticated && !login) return '/login';
    if (authSession.authenticated && login) return '/projects';
    return null;
  },
  routes: [
    GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
    GoRoute(
      path: '/projects/new',
      builder: (_, _) => const CreateProjectPage(),
    ),
    GoRoute(
      path: '/projects/:id/overview',
      builder:
          (_, state) =>
              ProjectOverviewPage(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/projects/:id/sources',
      builder:
          (_, state) => InputStudioPage(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/projects/:id/review-input',
      builder:
          (_, state) => InputReviewPage(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/projects/:id/builder/:step',
      builder:
          (_, state) => BuilderPage(
            projectId: state.pathParameters['id']!,
            step: int.tryParse(state.pathParameters['step'] ?? '1') ?? 1,
          ),
    ),
    GoRoute(
      path: '/projects/:id/preview',
      builder:
          (_, state) =>
              ProjectPreviewPage(projectId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/login', builder: (_, _) => const AuthPage()),
  ],
);

class ReqvioraApp extends StatelessWidget {
  const ReqvioraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'REQVIORA · Design Workspace',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    routerConfig: appRouter,
  );
}
