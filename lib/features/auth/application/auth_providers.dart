import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_session_provider.dart';
import '../../projects/application/projects_providers.dart';
import '../data/auth_repository.dart';
import '../domain/authenticated_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

/// The authenticated identity is fetched once per account generation. The
/// session-scoped ProviderScope destroys it on sign-out/account switches.
final authenticatedProfileProvider = FutureProvider<AuthenticatedProfile>((
  ref,
) async {
  ref.watch(authSessionGenerationProvider);
  final raw = await ref.watch(authRepositoryProvider).getProfile();
  return AuthenticatedProfile.fromJson(raw);
});
