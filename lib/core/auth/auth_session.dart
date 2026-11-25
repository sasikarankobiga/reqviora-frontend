import 'package:flutter/foundation.dart';

/// Session tokens are held in memory, never unencrypted browser storage.
/// Production token lifecycle and refresh/SSO need dedicated security review.
class AuthSession extends ChangeNotifier {
  String? _token;
  String? get token => _token;
  bool get authenticated => _token != null && _token!.isNotEmpty;
  void signIn(String token) {
    _token = token;
    notifyListeners();
  }

  void signOut() {
    _token = null;
    notifyListeners();
  }
}

final authSession = AuthSession();
