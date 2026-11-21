
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/project_api_service.dart';
import '../../domain/models/project_model.dart';

// Load projects belonging to the authenticated user.
final projectListProvider =
    FutureProvider.autoDispose<List<ProjectModel>>((ref) async {
  final session = await ref.watch(authProvider.future);

  if (session == null) {
    throw StateError('Please sign in to view your projects.');
  }

  return ref.read(projectApiServiceProvider).getProjects(
        accessToken: session.accessToken,
      );
});

// Provider for project creation and other actions.
final projectActionsProvider = Provider<ProjectActions>((ref) {
  return ProjectActions(ref);
});

class ProjectActions {
  final Ref ref;

  ProjectActions(this.ref);

  // Create a new project using the backend API.
  Future<ProjectModel> createProject({
    required String name,
    required String description,
    required String projectType,
    required String targetAudience,
  }) async {
    final session = await ref.read(authProvider.future);

    if (session == null) {
      throw StateError('Please sign in before creating a project.');
    }

    if (session.isAccessTokenExpired) {
      throw StateError(
        'Your session has expired. Please sign in again.',
      );
    }

    final project = await ref.read(projectApiServiceProvider).createProject(
          accessToken: session.accessToken,
          name: name,
          description: description,
          projectType: projectType,
          targetAudience: targetAudience,
        );

    // Refresh the project list after successful creation.
    ref.invalidate(projectListProvider);

    return project;
  }

  // Refresh the project list manually.
  void refreshProjects() {
    ref.invalidate(projectListProvider);
  }
}
