import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_session.dart';

class AuthRepository {
  const AuthRepository(this.api);
  final ApiClient api;

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

  Future<void> signIn(String email, String password, {String? otpCode}) async {
    final result = await api.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
      if (otpCode != null && otpCode.isNotEmpty) 'otpCode': otpCode,
    });
    if (result is! Map) throw StateError('Invalid authentication response');
    final token = result['accessToken']?.toString() ?? '';
    final refreshToken = result['refreshToken']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(
      result['accessTokenExpiresAt']?.toString() ?? '',
    );
    if (token.isEmpty || refreshToken.isEmpty || expiresAt == null) {
      throw StateError('Incomplete authentication token response');
    }
    authSession.startSession(
      accessToken: token,
      refreshToken: refreshToken,
      accessExpiresAt: expiresAt,
    );
  }

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
    } else {
      await signIn(email, password);
    }
  }

  Future<void> forgotPassword(String email) async {
    await api.post('/api/account-security/password/forgot', {
      'email': email.trim(),
    });
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await api.post('/api/account-security/password/reset', {
      'token': token,
      'newPassword': newPassword,
    });
  }

  Future<void> requestEmailVerification() async {
    await api.post('/api/account-security/email-verification/request', {});
  }

  Future<void> confirmEmailVerification(String token) async {
    await api.post('/api/account-security/email-verification/confirm', {
      'token': token,
    });
  }

  Future<Map<String, dynamic>> provisionMfa() async {
    final response = await api.post('/api/security/mfa/provision', {});
    if (response is! Map) throw StateError('Invalid MFA provisioning response');
    return Map<String, dynamic>.from(response);
  }

  Future<void> verifyMfa(String code) async {
    await api.post('/api/security/mfa/verify', {'code': code});
  }

  Future<void> logout() async {
    final refreshToken = authSession.refreshToken;
    try {
      if (refreshToken != null) {
        await api.post('/api/auth/logout', {'refreshToken': refreshToken});
      }
    } finally {
      authSession.signOut();
    }
  }

  void signOut() => authSession.signOut();
}
