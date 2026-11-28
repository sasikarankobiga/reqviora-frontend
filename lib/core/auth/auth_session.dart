import 'package:flutter/foundation.dart';

/// Session tokens remain in memory. They are never written to script-readable
/// browser storage. Secure refresh restoration requires an HttpOnly backend
/// cookie; until that contract exists, refresh safely returns to sign-in.
enum AuthSessionPhase { signInRequired, restoring, authenticated, expired }

class AuthSession extends ChangeNotifier {
  int _generation = 0;

  final ValueNotifier<int> _generationSignal = ValueNotifier<int>(0);

  String? _token;
  String? _refreshToken;
  DateTime? _accessExpiresAt;
  AuthSessionPhase _phase = AuthSessionPhase.signInRequired;

  int get generation => _generation;

  ValueListenable<int> get generationListenable => _generationSignal;

  String? get token => _token;

  String? get refreshToken => _refreshToken;

  DateTime? get accessExpiresAt => _accessExpiresAt;

  AuthSessionPhase get phase => _phase;

  bool get authenticated => _token != null && _token!.isNotEmpty;

  void _advanceGeneration() {
    _generation++;
    _generationSignal.value = _generation;
  }

  /// Compatible with existing widget tests and one-token demo sessions.
  void signIn(String token) {
    _token = token;
    _refreshToken = null;
    _accessExpiresAt = null;
    _phase = AuthSessionPhase.authenticated;

    _advanceGeneration();
    notifyListeners();
  }

  void startSession({
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
  }) {
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw StateError('Missing authentication credentials');
    }

    _token = accessToken;
    _refreshToken = refreshToken;
    _accessExpiresAt = accessExpiresAt.toUtc();
    _phase = AuthSessionPhase.authenticated;

    _advanceGeneration();
    notifyListeners();
  }

  /// Replaces credentials only when the refresh response still belongs
  /// to the expected session and refresh token.
  bool replaceRefreshedSession({
    required int expectedGeneration,
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
  }) {
    return refreshSession(
      expectedGeneration: expectedGeneration,
      expectedRefreshToken: expectedRefreshToken,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessExpiresAt: accessExpiresAt,
    );
  }

  /// Supports existing refresh callers from both branches.
  /// Callers should provide expectedRefreshToken for stale-response protection.
  bool refreshSession({
    required int expectedGeneration,
    String? expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
  }) {
    if (_generation != expectedGeneration || !authenticated) {
      return false;
    }

    if (expectedRefreshToken != null && _refreshToken != expectedRefreshToken) {
      return false;
    }

    if (accessToken.trim().isEmpty ||
        refreshToken.trim().isEmpty ||
        !accessExpiresAt.isAfter(DateTime.now().toUtc())) {
      return false;
    }

    _token = accessToken;
    _refreshToken = refreshToken;
    _accessExpiresAt = accessExpiresAt.toUtc();
    _phase = AuthSessionPhase.authenticated;

    notifyListeners();

    return true;
  }

  void signOut({bool expired = false}) {
    _token = null;
    _refreshToken = null;
    _accessExpiresAt = null;
    _phase =
        expired ? AuthSessionPhase.expired : AuthSessionPhase.signInRequired;

    _advanceGeneration();
    notifyListeners();
  }

  @override
  void dispose() {
    _generationSignal.dispose();
    super.dispose();
  }
}

final authSession = AuthSession();
