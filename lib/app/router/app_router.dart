
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/projects/presentation/pages/create_project_page.dart';
import '../../features/projects/presentation/pages/project_overview_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  routes: [
    // Redirect root to Login.
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),

    // Login Page.
    GoRoute(
      path: '/login',
      builder: (context, state) {
        return const LoginPage();
      },
    ),

    // Register Page.
    GoRoute(
      path: '/register',
      builder: (context, state) {
        return const RegisterPage();
      },
    ),

    // Task 3: Dashboard Page.
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        return const DashboardPage();
      },
    ),

    // Task 3: Create Project Page.
    GoRoute(
      path: '/projects/create',
      builder: (context, state) {
        return const CreateProjectPage();
      },
    ),

    // Task 3: Project Overview Page.
    GoRoute(
      path: '/projects/:projectId',
      builder: (context, state) {
        final projectId = state.pathParameters['projectId']!;

        return ProjectOverviewPage(
          projectId: projectId,
        );
      },
    ),

    // Temporary Welcome Page.
    GoRoute(
      path: '/welcome',
      builder: (context, state) {
        return const Scaffold(
          body: Center(
            child: Text(
              'REQVIORA - Welcome',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    ),
  ],
);
