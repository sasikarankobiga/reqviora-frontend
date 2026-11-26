import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/projects/presentation/projects_page.dart';
import '../features/projects/presentation/create_project_page.dart';
import '../features/projects/presentation/project_overview_page.dart';
import '../features/builder/presentation/builder_page.dart';
import '../features/prebuilder/presentation/prebuilder_pages.dart';
import 'theme.dart';
import '../features/administration/presentation/pages/admin_page.dart';
import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/account_security_pages.dart';
import '../features/workspace/presentation/preview_page.dart';
import '../l10n/app_localizations.dart';

final appRouter = GoRouter(
  initialLocation: '/projects',
  refreshListenable: authSession,
  redirect: (_, state) {
    if (isLocalDemo) {
      if (state.matchedLocation == '/admin') return '/projects';
      return null;
    }
    final signInPages =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';
    final publicAuth =
        signInPages ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/reset-password' ||
        state.matchedLocation == '/verify-email';
    if (!authSession.authenticated && !publicAuth) return '/login';
    if (authSession.authenticated && signInPages) return '/projects';
    return null;
  },
  routes: [
    GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
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
    GoRoute(
      path: '/login',
      builder:
          (_, state) => AuthPage(
            showRegistrationSuccess:
                state.uri.queryParameters['registered'] == '1',
          ),
    ),
    GoRoute(
      path: '/register',
      builder: (_, _) => const AuthPage(register: true),
    ),
    GoRoute(
      path: '/forgot-password',
      builder:
          (_, _) =>
              const AccountSecurityPage(action: AccountAction.forgotPassword),
    ),
    GoRoute(
      path: '/reset-password',
      builder:
          (_, state) => AccountSecurityPage(
            action: AccountAction.resetPassword,
            token: state.uri.queryParameters['token'] ?? '',
          ),
    ),
    GoRoute(
      path: '/verify-email',
      builder:
          (_, state) => AccountSecurityPage(
            action: AccountAction.verifyEmail,
            token: state.uri.queryParameters['token'] ?? '',
          ),
    ),
    GoRoute(
      path: '/security/mfa',
      builder:
          (_, _) => const AccountSecurityPage(action: AccountAction.setupMfa),
    ),
  ],
);

class ReqvioraApp extends StatelessWidget {
  const ReqvioraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'REQVIORA · Design Workspace',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: appRouter,
  );
}
