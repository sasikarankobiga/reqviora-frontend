import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_session.dart';

class RegistrationVerificationPending extends ApiException {
  RegistrationVerificationPending({
    required String accessToken,
    required DateTime expiresAt,
    required int generation,
  }) : _accessToken = accessToken,
       _expiresAt = expiresAt,
       _generation = generation,
       super(
         424,
         'Account created, but email verification could not be requested.',
       );

  String? _accessToken;
  final DateTime _expiresAt;
  final int _generation;
  bool _retrying = false;

  bool get canRetry =>
      _accessToken != null &&
      _generation == authSession.generation &&
      _expiresAt.isAfter(DateTime.now().toUtc());

  void clear() {
    _accessToken = null;
  }
}

class AuthRepository {
  const AuthRepository(this.api);
  final ApiClient api;

  Future<void> registerAccount(
    String email,
    String password,
    String displayName,
  ) async {
    final generation = authSession.generation;

    final result = await api.post('/api/auth/register', {
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
    });

    if (authSession.generation != generation) {
      throw const ApiException(401, 'The session changed during registration.');
    }

    if (result is! Map) {
      throw const ApiException(502, 'Invalid registration response.');
    }

    final accessToken = result['accessToken'];
    final expiresValue = result['accessTokenExpiresAt'];

    if (accessToken is! String ||
        accessToken.trim().isEmpty ||
        expiresValue is! String) {
      throw const ApiException(502, 'Invalid registration credentials.');
    }

    final expiresAt = DateTime.tryParse(expiresValue);

    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const ApiException(502, 'Registration credential has expired.');
    }

    try {
      // Registration credentials must not unlock the workspace.
      await api.requestRegistrationVerification(accessToken);
    } on ApiException {
      throw RegistrationVerificationPending(
        accessToken: accessToken,
        expiresAt: expiresAt,
        generation: generation,
      );
    }
  }

  Future<void> retryRegistrationVerification(
    RegistrationVerificationPending pending,
  ) async {
    if (!pending.canRetry) {
      pending.clear();

      throw const ApiException(
        410,
        'Verification retry has expired. Contact support.',
      );
    }

    if (pending._retrying) {
      throw const ApiException(
        429,
        'A verification request is already running.',
      );
    }

    pending._retrying = true;

    try {
      await api.requestRegistrationVerification(pending._accessToken!);

      pending.clear();
    } finally {
      pending._retrying = false;

      if (!pending.canRetry) {
        pending.clear();
      }
    }
  }

  static int _loginAttempt = 0;

  Future<void> signIn(String email, String password, {String? otpCode}) async {
    final attempt = ++_loginAttempt;
    final generation = authSession.generation;

    final result = await api.post('/api/auth/login', {
      'email': email.trim(),
      'password': password,
      if (otpCode != null && otpCode.isNotEmpty) 'otpCode': otpCode,
    });

    if (attempt != _loginAttempt || generation != authSession.generation) {
      throw const ApiException(
        401,
        'The authentication session changed. Please sign in again.',
      );
    }

    if (result is! Map) {
      throw const ApiException(502, 'Invalid authentication response.');
    }

    final token = result['accessToken'];
    final refreshToken = result['refreshToken'];
    final expiresValue = result['accessTokenExpiresAt'];

    if (token is! String ||
        refreshToken is! String ||
        expiresValue is! String ||
        token.trim().isEmpty ||
        refreshToken.trim().isEmpty) {
      throw const ApiException(502, 'Incomplete authentication credentials.');
    }

    final expiresAt = DateTime.tryParse(expiresValue);

    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const ApiException(502, 'Invalid authentication token expiry.');
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

  Future<Map<String, dynamic>> getProfile() async {
    final result = await api.get('/api/users/me');

    if (result is! Map<String, dynamic>) {
      throw const ApiException(502, 'Invalid account profile response.');
    }

    return result;
  }

  Future<void> requestEmailChange(String newEmail) async {
    final email = newEmail.trim();

    if (!authSession.authenticated) {
      throw const ApiException(401, 'Sign in before changing your email.');
    }

    if (email.isEmpty || email.length > 320 || !email.contains('@')) {
      throw ArgumentError('Enter a valid email address.');
    }

    await api.post('/api/account-security/email-change/request', {
      'newEmail': email,
    });
  }

  Future<void> confirmEmailChange(String token) async {
    if (token.trim().isEmpty) {
      throw ArgumentError('Email change confirmation token is required.');
    }

    final generation = authSession.generation;

    await api.post('/api/account-security/email-change/confirm', {
      'token': token,
    });

    // The backend revokes existing refresh sessions after confirmation.
    if (authSession.generation == generation) {
      signOut();
    }
  }

  Future<void> forgotPassword(String email) async {
    await api.post('/api/account-security/password/forgot', {
      'email': email.trim(),
    });
  }

  Future<void> resetPassword(String token, String newPassword) async {
    if (token.trim().isEmpty) {
      throw ArgumentError('Password reset token is required.');
    }

    final generation = authSession.generation;

    await api.post('/api/account-security/password/reset', {
      'token': token,
      'newPassword': newPassword,
    });

    // The server revokes existing refresh sessions on successful reset.
    // Never clear a newer session established by another login.
    if (authSession.generation == generation) {
      signOut();
    }
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
    final generation = authSession.generation;
    final refreshToken = authSession.refreshToken;

    _loginAttempt++;

    try {
      if (refreshToken != null) {
        await api.post('/api/auth/logout', {'refreshToken': refreshToken});
      }
    } finally {
      if (authSession.generation == generation) {
        authSession.signOut();
      }
    }
  }

  void signOut() {
    _loginAttempt++;
    authSession.signOut();
  }
}
