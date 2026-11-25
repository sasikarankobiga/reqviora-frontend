import 'dart:convert';

/// Local, JSON-compatible Blueprint editing history.
///
/// This class never writes to the server.
class V4BlueprintHistory {
  V4BlueprintHistory(
    Map<String, dynamic> initial, {
    this.maxHistory = 50,
  }) : assert(maxHistory > 0) {
    _current = _copy(initial);
  }

  final int maxHistory;

  final List<Map<String, dynamic>> _past = [];
  final List<Map<String, dynamic>> _future = [];

  late Map<String, dynamic> _current;

  static Map<String, dynamic> _copy(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(
      jsonDecode(jsonEncode(source)) as Map,
    );
  }

  Map<String, dynamic> get current => _copy(_current);

  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;

  int get undoCount => _past.length;
  int get redoCount => _future.length;

  bool record(Map<String, dynamic> next) {
    final snapshot = _copy(next);

    if (jsonEncode(snapshot) == jsonEncode(_current)) {
      return false;
    }

    _past.add(_copy(_current));

    if (_past.length > maxHistory) {
      _past.removeAt(0);
    }

    _current = snapshot;
    _future.clear();

    return true;
  }

  Map<String, dynamic>? undo() {
    if (!canUndo) return null;

    _future.add(_copy(_current));
    _current = _past.removeLast();

    return current;
  }

  Map<String, dynamic>? redo() {
    if (!canRedo) return null;

    _past.add(_copy(_current));
    _current = _future.removeLast();

    return current;
  }

  void reset(Map<String, dynamic> blueprint) {
    _current = _copy(blueprint);
    _past.clear();
    _future.clear();
  }
}
