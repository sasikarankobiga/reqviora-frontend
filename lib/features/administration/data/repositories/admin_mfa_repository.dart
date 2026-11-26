import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';

class AdminMfaProvision {
  const AdminMfaProvision._({
    required this.secret,
    required this.uri,
    required this.recoveryCodes,
  });

  final String secret;
  final String uri;
  final List<String> recoveryCodes;
}

/// Adapter for the Admin MFA contract in
/// backend/feature/kobiga-core-workflow.
/// Must not replace normal user MFA.
class AdminMfaRepository {
  const AdminMfaRepository(this.api);

  final ApiClient api;

  static const basePath = '/api/security/admin-mfa';

  String _email(String value) {
    final email = value.trim();

    if (email.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ArgumentError('Invalid email address.');
    }

    return email;
  }

  void _token(String token) {
    if (token.length < 32 ||
        token.length > 512 ||
        token.trim() != token ||
        RegExp(r'\s').hasMatch(token)) {
      throw ArgumentError('Invalid enrollment credential.');
    }
  }

  void _checkSession(int generation) {
    if (generation != authSession.generation) {
      throw const ApiException(401, 'The account session changed.');
    }
  }

  Future<void> requestBootstrap({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _email(email);

    if (password.length < 8 || password.length > 128) {
      throw ArgumentError('Invalid password length.');
    }

    final generation = authSession.generation;

    await api.post('$basePath/bootstrap/request', {
      'email': normalizedEmail,
      'password': password,
    });

    _checkSession(generation);
  }

  Future<void> requestRecovery({required String adminEmail}) async {
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Sign in is required.');
    }

    final generation = authSession.generation;

    await api.post('$basePath/recovery/request', {
      'adminEmail': _email(adminEmail),
    });

    _checkSession(generation);
  }

  Future<AdminMfaProvision> provision({required String token}) async {
    _token(token);

    final generation = authSession.generation;

    final raw = await api.post('$basePath/provision', {'token': token});

    _checkSession(generation);

    if (raw is! Map) {
      throw const FormatException('Invalid MFA provisioning response.');
    }

    final secret = raw['secret'];
    final uri = raw['uri'];
    final codes = raw['recoveryCodes'];

    if (secret is! String ||
        !RegExp(r'^[A-Z2-7]{32}$').hasMatch(secret) ||
        uri is! String ||
        uri.length > 2048 ||
        codes is! List ||
        codes.length != 8) {
      throw const FormatException('Invalid MFA provisioning data.');
    }

    final parsed = Uri.tryParse(uri);

    if (parsed == null ||
        parsed.scheme != 'otpauth' ||
        parsed.host != 'totp' ||
        !parsed.path.startsWith('/REQVIORA:') ||
        parsed.queryParametersAll['secret']?.length != 1 ||
        parsed.queryParametersAll['issuer']?.length != 1 ||
        parsed.queryParameters['secret'] != secret ||
        parsed.queryParameters['issuer'] != 'REQVIORA' ||
        parsed.hasFragment ||
        parsed.userInfo.isNotEmpty) {
      throw const FormatException('Invalid authenticator URI.');
    }

    final validatedCodes = <String>[];

    for (final code in codes) {
      if (code is! String ||
          !RegExp(r'^[a-f0-9]{10}$').hasMatch(code) ||
          validatedCodes.contains(code)) {
        throw const FormatException('Invalid recovery codes.');
      }

      validatedCodes.add(code);
    }

    return AdminMfaProvision._(
      secret: secret,
      uri: uri,
      recoveryCodes: List.unmodifiable(validatedCodes),
    );
  }

  Future<void> verify({required String token, required String code}) async {
    _token(token);

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      throw ArgumentError('A six-digit authenticator code is required.');
    }

    final generation = authSession.generation;

    await api.post('$basePath/verify', {'token': token, 'code': code});

    _checkSession(generation);

    // Successful verification revokes server refresh sessions.
    // Clear the existing local session conservatively.
    if (authSession.authenticated) {
      authSession.signOut();
    }
  }
}
