
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/datasources/project_api_service.dart';
import '../../domain/models/project_overview_model.dart';

// Load the overview of one authenticated project.
final projectOverviewProvider =
    FutureProvider.autoDispose.family<ProjectOverviewModel, String>(
  (ref, projectId) async {
    if (projectId.trim().isEmpty) {
      throw ArgumentError('Project ID is required.');
    }

    // Get the current authenticated session.
    final session = await ref.watch(authProvider.future);

    if (session == null) {
      throw StateError(
        'Please sign in to view the project overview.',
      );
    }

    if (session.isAccessTokenExpired) {
      throw StateError(
        'Your session has expired. Please sign in again.',
      );
    }

    // Request the real project overview from the backend.
    final overview =
        await ref.read(projectApiServiceProvider).getProjectOverview(
              projectId: projectId,
              accessToken: session.accessToken,
            );

    return overview;
  },
);
