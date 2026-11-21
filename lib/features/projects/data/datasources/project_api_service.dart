
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../domain/models/project_model.dart';
import '../../domain/models/project_overview_model.dart';

class ProjectApiService {
  final Dio dio;

  ProjectApiService(this.dio);

  // Add JWT access token to protected requests.
  Options _authOptions(String accessToken) {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError('Access token is required.');
    }

    return Options(
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
  }

  // GET /api/projects
  // Retrieve projects accessible to the logged-in user.
  Future<List<ProjectModel>> getProjects({
    required String accessToken,
  }) async {
    final response = await dio.get(
      '/api/projects',
      options: _authOptions(accessToken),
    );

    final data = response.data as List<dynamic>;

    return data
        .map(
          (item) => ProjectModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  // GET /api/projects/{id}
  // Retrieve a single project.
  Future<ProjectModel> getProjectById({
    required String projectId,
    required String accessToken,
  }) async {
    final response = await dio.get(
      '/api/projects/$projectId',
      options: _authOptions(accessToken),
    );

    return ProjectModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // NEW: GET /api/projects/{projectId}/overview
  // Retrieve project overview using JWT authentication.
  Future<ProjectOverviewModel> getProjectOverview({
    required String projectId,
    required String accessToken,
  }) async {
    if (projectId.trim().isEmpty) {
      throw ArgumentError('Project ID is required.');
    }

    final response = await dio.get(
      '/api/projects/${Uri.encodeComponent(projectId)}/overview',
      options: _authOptions(accessToken),
    );

    return ProjectOverviewModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // POST /api/projects
  // Create a new project.
  Future<ProjectModel> createProject({
    required String accessToken,
    required String name,
    required String description,
    required String projectType,
    required String targetAudience,
  }) async {
    final response = await dio.post(
      '/api/projects',
      options: _authOptions(accessToken),
      data: {
        'name': name.trim(),
        'description': description.trim(),
        'projectType': projectType,
        'targetAudience': targetAudience.trim(),
        'primaryPlatform': 'web',
      },
    );

    return ProjectModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  // PUT /api/projects/{id}
  // Update the supplied project details.
  Future<ProjectModel> updateProject({
    required String projectId,
    required String accessToken,
    required String name,
    required String description,
    required String industry,
    required String targetAudience,
    required String projectType,
    required String primaryPlatform,
    required String technologyPreferences,
    required String constraints,
    required String integrations,
  }) async {
    final response = await dio.put(
      '/api/projects/$projectId',
      options: _authOptions(accessToken),
      data: {
        'name': name.trim(),
        'description': description.trim(),
        'industry': industry.trim(),
        'targetAudience': targetAudience.trim(),
        'projectType': projectType,
        'primaryPlatform': primaryPlatform,
        'technologyPreferences': technologyPreferences.trim(),
        'constraints': constraints.trim(),
        'integrations': integrations.trim(),
      },
    );

    return ProjectModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

// Reuse the existing Dio client.
final projectApiServiceProvider = Provider<ProjectApiService>((ref) {
  return ProjectApiService(ref.watch(dioProvider));
});
