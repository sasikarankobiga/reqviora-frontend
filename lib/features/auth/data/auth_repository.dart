import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_session.dart';

class AuthRepository {
  const AuthRepository(this.api);

  final ApiClient api;

  // Register without automatically signing in.
  Future<void> registerAccount(
    String email,
    String password,
    String displayName,
  ) async {
    await api.post('/api/auth/register', {
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
    });
  }

  // Sign in using REQVIORA ASP.NET Core API.
  Future<void> signIn(String email, String password, {String? otpCode}) async {
    final result = await api.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
      if (otpCode != null && otpCode.isNotEmpty) 'otpCode': otpCode,
    });

    if (result is! Map) {
      throw StateError('Invalid authentication response');
    }

    final token = result['accessToken']?.toString();

    if (token == null || token.isEmpty) {
      throw StateError('Authentication token missing');
    }

    authSession.signIn(token);
  }

  // Compatibility with existing application callers.
  Future<void> authenticate(
    String email,
    String password, {
    bool register = false,
    String? displayName,
  }) async {
    if (register) {
      if (displayName == null || displayName.trim().length < 2) {
        throw ArgumentError('Display name is required for registration');
      }

      await registerAccount(email, password, displayName);
      return;
    }

    await signIn(email, password);
  }

  void signOut() {
    authSession.signOut();
  }
}
