import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_session.dart';

/// Invalidates private provider caches only when account identity changes.
/// Access-token rotation deliberately keeps the same generation.
final authSessionGenerationProvider = Provider<int>((ref) {
  void invalidate() => ref.invalidateSelf();

  authSession.generationListenable.addListener(invalidate);
  ref.onDispose(
    () => authSession.generationListenable.removeListener(invalidate),
  );
  return authSession.generation;
});
