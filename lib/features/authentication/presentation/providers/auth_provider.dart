
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/auth_api_service.dart';
import '../../domain/models/auth_session.dart';

// Authentication state:
// loading, error, or an authenticated session.
final authProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    // Initially, the user is not logged in.
    return null;
  }

  // Login using the real backend API.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      final response = await ref.read(
        authApiServiceProvider,
      ).login(
        email: email,
        password: password,
      );

      final session = AuthSession.fromJson(response);

      state = AsyncData(session);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  // Register using the real backend API.
  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      final response = await ref.read(
        authApiServiceProvider,
      ).register(
        displayName: displayName,
        email: email,
        password: password,
      );

      final session = AuthSession.fromJson(response);

      state = AsyncData(session);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  // Logout from the backend.
  Future<void> logout() async {
    final session = state.value;

    if (session == null) {
      state = const AsyncData(null);
      return;
    }

    try {
      await ref.read(authApiServiceProvider).logout(
        refreshToken: session.refreshToken,
      );
    } finally {
      // Clear local authentication state.
      state = const AsyncData(null);
    }
  }
}
