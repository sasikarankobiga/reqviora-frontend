import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/background_jobs/presentation/pages/ai_job_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/projects/presentation/create_project_page.dart';
import '../features/projects/presentation/project_overview_page.dart';
import '../features/projects/presentation/project_invitation_response_page.dart';
import '../features/billing/presentation/billing_page.dart';
import '../features/builder/presentation/builder_page.dart';
import '../features/prebuilder/presentation/prebuilder_pages.dart';

import 'theme.dart';

import '../l10n/app_localizations.dart';
import '../l10n/language_settings.dart';

import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';

import '../features/auth/presentation/auth_page.dart';
import '../features/auth/presentation/account_security_pages.dart';
import '../features/auth/presentation/account_profile_page.dart';
import '../features/auth/domain/verification_link.dart';

import '../features/administration/presentation/pages/admin_page.dart';
import '../features/administration/presentation/pages/admin_dashboard_page.dart';
import '../features/administration/presentation/pages/admin_export_diagnostics_page.dart';
import '../features/administration/presentation/pages/admin_mcp_grants_page.dart';
import '../features/administration/presentation/pages/validation_health_page.dart';
import '../features/administration/presentation/pages/ai_queue_monitoring_page.dart';
import '../features/administration/presentation/pages/admin_profile_sessions_page.dart';
import '../features/administration/presentation/pages/admin_billing_page.dart';
import '../features/administration/presentation/pages/admin_settings_incidents_page.dart';

import '../features/workspace/presentation/preview_page.dart';
import '../features/workspace/presentation/project_write_gate.dart';

String? safeLocalDestination(String? candidate) {
  if (candidate == null || candidate.isEmpty || !candidate.startsWith('/')) {
    return null;
  }
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      candidate.startsWith('//')) {
    return null;
  }
  if (uri.path == '/login' || uri.path == '/register') return null;
  return uri.toString();
}

final appRouter = GoRouter(
  initialLocation: '/projects',
  refreshListenable: authSession,

  redirect: (_, state) {
    if (isLocalDemo) {
      if (state.matchedLocation == '/admin' ||
          state.matchedLocation == '/administration' ||
          state.matchedLocation == '/ai-jobs') {
        return '/projects';
      }

      return null;
    }

    final invitationResponse =
        state.matchedLocation == '/project-invitations/respond';

    if (!authSession.authenticated && invitationResponse) {
      pendingInvitationResponse.capture(
        state.uri.queryParameters['token'] ?? '',
      );
      return '/login?invitation=1';
    }

    final signInPages =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    final publicAuth =
        signInPages ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/reset-password' ||
        state.matchedLocation == '/verify-email' ||
        state.matchedLocation == '/confirm-email-change';

    if (!authSession.authenticated && !publicAuth) {
      return Uri(
        path: '/login',
        queryParameters: {'from': state.uri.toString()},
      ).toString();
    }

    if (authSession.authenticated && signInPages) {
      final invitationToken = pendingInvitationResponse.take();
      if (invitationToken != null) {
        return Uri(
          path: '/project-invitations/respond',
          queryParameters: {'token': invitationToken},
        ).toString();
      }
      return safeLocalDestination(state.uri.queryParameters['from']) ??
          '/projects';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),

    GoRoute(
      path: '/admin/mcp-grants',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AdminMcpGrantsPage(),
    ),

    GoRoute(
      path: '/admin/export-diagnostics',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AdminExportDiagnosticsPage(),
    ),

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
      path: '/project-invitations/respond',
      builder:
          (_, state) => ProjectInvitationResponsePage(
            token: state.uri.queryParameters['token'] ?? '',
          ),
    ),

    GoRoute(
      path: '/projects/:id/billing',
      builder:
          (_, state) => BillingPage(projectId: state.pathParameters['id']!),
    ),

    GoRoute(
      path: '/projects/:id/sources',
      builder: (_, state) {
        final id = state.pathParameters['id']!;

        return Scaffold(
          body: ProjectWriteGate(
            projectId: id,
            ownerOnly: true,
            child: InputStudioPage(projectId: id),
          ),
        );
      },
    ),

    GoRoute(
      path: '/projects/:id/review-input',
      builder: (_, state) {
        final id = state.pathParameters['id']!;

        return Scaffold(
          body: ProjectWriteGate(
            projectId: id,
            ownerOnly: true,
            child: InputReviewPage(projectId: id),
          ),
        );
      },
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
            postSignInPath: safeLocalDestination(
              state.uri.queryParameters['from'],
            ),
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
            token: verificationTokenFromUri(state.uri),
          ),
    ),

    GoRoute(path: '/account', builder: (_, _) => const AccountProfilePage()),

    GoRoute(
      path: '/ai-jobs',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AiJobPage(),
    ),

    GoRoute(
      path: '/administration',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AdminDashboardPage(),
    ),

    GoRoute(
      path: '/administration/validation-health',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const ValidationHealthPage(),
    ),

    GoRoute(
      path: '/administration/ai-queue',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AiQueueMonitoringPage(),
    ),
    GoRoute(
      path: '/administration/settings-incidents',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AdminSettingsIncidentsPage(),
    ),

    GoRoute(
      path: '/administration/profile-sessions',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AdminProfileSessionsPage(),
    ),

    GoRoute(
      path: '/administration/billing',
      redirect: (_, _) => isLocalDemo ? '/projects' : null,
      builder: (_, _) => const AdminBillingPage(),
    ),

    GoRoute(
      path: '/confirm-email-change',
      builder:
          (_, state) => AccountProfilePage(
            confirmChange: true,
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
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: appLocale,
    builder:
        (context, locale, _) => MaterialApp.router(
          title: 'REQVIORA · Design Workspace',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          routerConfig: appRouter,
          locale: effectiveAppLocale(
            locale,
            WidgetsBinding.instance.platformDispatcher.locales,
          ),
          supportedLocales: supportedAppLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
  );
}
