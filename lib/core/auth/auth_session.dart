import 'package:flutter/foundation.dart';

/// Session tokens remain in memory. They are never written to browser storage.
/// A page refresh intentionally requires re-authentication.
class AuthSession extends ChangeNotifier {
  String? _token;
  String? _refreshToken;
  DateTime? _accessExpiresAt;
  int _generation = 0;
  final ValueNotifier<int> _generationSignal = ValueNotifier<int>(0);

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  DateTime? get accessExpiresAt => _accessExpiresAt;
  int get generation => _generation;
  ValueListenable<int> get generationListenable => _generationSignal;
  bool get authenticated => _token != null && _token!.isNotEmpty;

  void _advanceGeneration() {
    _generation++;
    _generationSignal.value = _generation;
  }

  /// Compatible with existing widget tests and one-token demo sessions.
  void signIn(String token) {
    _advanceGeneration();
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
    _advanceGeneration();
    _token = accessToken;
    _refreshToken = refreshToken;
    _accessExpiresAt = accessExpiresAt.toUtc();
    notifyListeners();
  }

  bool refreshSession({
    required int expectedGeneration,
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
  }) {
    if (expectedGeneration != _generation || !authenticated) return false;
    if (accessToken.isEmpty || refreshToken.isEmpty) return false;
    _token = accessToken;
    _refreshToken = refreshToken;
    _accessExpiresAt = accessExpiresAt.toUtc();
    notifyListeners();
    return true;
  }

  void signOut() {
    final hadSession =
        _token != null || _refreshToken != null || _accessExpiresAt != null;
    _token = null;
    _refreshToken = null;
    _accessExpiresAt = null;
    if (hadSession) _advanceGeneration();
    notifyListeners();
  }
}

final authSession = AuthSession();
