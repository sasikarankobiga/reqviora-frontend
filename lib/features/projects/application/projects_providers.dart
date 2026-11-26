import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_session_provider.dart';
import '../domain/project.dart';
import '../domain/projects_repository.dart';
import '../data/http_projects_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(http.Client());
  ref.onDispose(client.dispose);
  return client;
});
final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => HttpProjectsRepository(ref.watch(apiClientProvider)),
);
final projectsProvider = FutureProvider<List<ProjectSummary>>((ref) {
  ref.watch(authSessionGenerationProvider);
  return ref.watch(projectsRepositoryProvider).list();
});
final projectDraftProvider = FutureProvider.family<ProjectDraft, String>((
  ref,
  id,
) {
  ref.watch(authSessionGenerationProvider);
  return ref.watch(projectsRepositoryProvider).draft(id);
});
