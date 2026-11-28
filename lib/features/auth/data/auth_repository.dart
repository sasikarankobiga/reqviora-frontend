import '../../../core/network/api_client.dart';
import '../../../core/auth/auth_session.dart';
import '../domain/registration_result.dart';

class AuthRepository {
  AuthRepository(this.api);

  final ApiClient api;

  static int _loginAttempt = 0;
  Future<RegistrationResult>? _registrationInFlight;
  String? _registrationKey;

  Future<RegistrationResult> registerAccount(
    String email,
    String password,
    String displayName,
  ) {
    final normalizedEmail = email.trim();
    final normalizedDisplayName = displayName.trim();
    final key = '$normalizedEmail\u0000$password\u0000$normalizedDisplayName';
    final pending = _registrationInFlight;

    if (pending != null) {
      if (_registrationKey == key) return pending;
      throw const ApiException(
        429,
        'A registration request is already running.',
      );
    }

    late final Future<RegistrationResult> request;
    request = _registerAccount(
      normalizedEmail,
      password,
      normalizedDisplayName,
    ).whenComplete(() {
      if (identical(_registrationInFlight, request)) {
        _registrationInFlight = null;
        _registrationKey = null;
      }
    });
    _registrationKey = key;
    _registrationInFlight = request;
    return request;
  }

  Future<RegistrationResult> _registerAccount(
    String email,
    String password,
    String displayName,
  ) async {
    final generation = authSession.generation;

    final result = await api.post('/api/auth/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
    });

    if (authSession.generation != generation) {
      throw const ApiException(401, 'The session changed during registration.');
    }

    if (result is! Map<Object?, Object?>) {
      throw const ApiException(502, 'Invalid registration response.');
    }

    return RegistrationResult.fromJson(result);
  }

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

    // The backend revokes existing refresh sessions
    // after confirmation.
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

    // The server revokes existing refresh sessions
    // on successful reset.
    // Never clear a newer session established
    // by another login.
    if (authSession.generation == generation) {
      signOut();
    }
  }

  Future<void> requestEmailVerification() async {
    await api.post('/api/account-security/email-verification/request', {});
  }

  Future<void> resendEmailVerification(String emailAddress) async {
    final email = emailAddress.trim();
    if (email.isEmpty ||
        email.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ArgumentError('Enter a valid email address.');
    }

    await api.post('/api/account-security/email-verification/resend', {
      'email': email,
    });
  }

  Future<void> confirmEmailVerification(String token) async {
    if (token.trim().isEmpty) {
      throw ArgumentError('Email verification token is required.');
    }

    await api.post('/api/account-security/email-verification/confirm', {
      'token': token,
    });
  }

  Future<Map<String, dynamic>> provisionMfa() async {
    final response = await api.post('/api/security/mfa/provision', {});

    if (response is! Map) {
      throw StateError('Invalid MFA provisioning response');
    }

    final uri = response['uri'];
    final rawCodes = response['recoveryCodes'];

    if (uri is! String ||
        uri.trim().isEmpty ||
        rawCodes is! List ||
        rawCodes.any((code) => code is! String || code.trim().isEmpty)) {
      throw StateError('Invalid MFA provisioning response');
    }

    return {'uri': uri, 'recoveryCodes': List<String>.from(rawCodes)};
  }

  Future<void> verifyMfa(String code) async {
    await api.post('/api/security/mfa/verify', {'code': code});
  }

  Future<void> logout() async {
    final generation = authSession.generation;
    final refreshToken = authSession.refreshToken;

    // Invalidate any login request currently in progress.
    _loginAttempt++;

    try {
      if (refreshToken != null) {
        await api.post('/api/auth/logout', {'refreshToken': refreshToken});
      }
    } finally {
      // Do not clear a newer authentication session.
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
