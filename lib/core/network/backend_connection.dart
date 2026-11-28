import 'package:flutter/foundation.dart';

enum BackendConnectionPhase {
  idle,
  connecting,
  active,
  reconnecting,
  unavailable,
}

class BackendConnection extends ChangeNotifier {
  BackendConnectionPhase _phase = BackendConnectionPhase.idle;

  BackendConnectionPhase get phase => _phase;

  void setPhase(BackendConnectionPhase value) {
    if (_phase == value) return;
    _phase = value;
    notifyListeners();
  }
}

final backendConnection = BackendConnection();
