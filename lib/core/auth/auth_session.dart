import 'package:flutter/foundation.dart';

/// Session tokens remain in memory. They are never written to browser storage.
/// A page refresh intentionally requires re-authentication.
class AuthSession extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  DateTime? _accessExpiresAt;

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  DateTime? get accessExpiresAt => _accessExpiresAt;
  bool get authenticated => _token != null && _token!.isNotEmpty;

  /// Compatible with existing widget tests and one-token demo sessions.
  void signIn(String token) {
    _token = token;
    _refreshToken = null;
    _accessExpiresAt = null;
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
    notifyListeners();
  }

  void signOut() {
    _token = null;
    _refreshToken = null;
    _accessExpiresAt = null;
    notifyListeners();
  }
}

final authSession = AuthSession();
