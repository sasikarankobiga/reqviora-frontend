import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_session.dart';

/// Each authentication generation owns a separate provider container.
/// Token refresh preserves the current generation and its cached data.
/// Signing in or out destroys the previous account's provider state.
class SessionProviderScope extends StatefulWidget {
  const SessionProviderScope({super.key, required this.child});

  final Widget child;

  @override
  State<SessionProviderScope> createState() => _SessionProviderScopeState();
}

class _SessionProviderScopeState extends State<SessionProviderScope> {
  late int _generation;

  @override
  void initState() {
    super.initState();
    _generation = authSession.generation;
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final nextGeneration = authSession.generation;

    if (!mounted || nextGeneration == _generation) {
      return;
    }

    setState(() {
      _generation = nextGeneration;
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(key: ValueKey<int>(_generation), child: widget.child);
  }
}
