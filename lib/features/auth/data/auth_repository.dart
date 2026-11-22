import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_session.dart';

class AuthRepository {
  const AuthRepository(this.api);
  final ApiClient api;
  Future<void> authenticate(
    String email,
    String password, {
    bool register = false,
  }) async {
    if (register) {
      await api.post('/api/auth/register', {
        'email': email,
        'password': password,
      });
    }
    final result = await api.post('/api/auth/login?useCookies=false', {
      'email': email,
      'password': password,
    });
    final token = (result as Map)['accessToken']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Authentication token missing');
    }
    authSession.signIn(token);
  }

  void signOut() => authSession.signOut();
}
