import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../data/repositories/admin_mfa_repository.dart';

/// Supervisor-initiated administrator MFA recovery.
/// Backend authorization remains mandatory.
class AdminMfaRecoveryPage extends StatefulWidget {
  const AdminMfaRecoveryPage({
    super.key,
    required this.repository,
    required this.canRequestRecovery,
  });

  final AdminMfaRepository repository;

  /// Must originate from verified permissions during route integration.
  final bool canRequestRecovery;

  @override
  State<AdminMfaRecoveryPage> createState() => _AdminMfaRecoveryPageState();
}

class _AdminMfaRecoveryPageState extends State<AdminMfaRecoveryPage> {
  final _email = TextEditingController();

  late final int _sessionGeneration;
  late final Timer _sessionGuard;

  bool _busy = false;
  bool _confirmed = false;
  bool _blocked = false;

  String? _message;
  String? _error;

  bool get _authorized =>
      widget.canRequestRecovery &&
      authSession.authenticated &&
      authSession.generation == _sessionGeneration;

  @override
  void initState() {
    super.initState();

    _sessionGeneration = authSession.generation;
    _blocked = !_authorized;

    _sessionGuard = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && !_authorized && !_blocked) {
        _invalidate();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AdminMfaRecoveryPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_authorized && !_blocked) {
      _invalidate();
    }
  }

  void _invalidate() {
    if (!mounted) return;

    _email.clear();

    setState(() {
      _blocked = true;
      _busy = false;
      _confirmed = false;
      _message = null;
      _error = null;
    });
  }

  bool _guard() {
    if (!mounted || _blocked) return false;

    if (!_authorized) {
      _invalidate();
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    if (!_guard() || _busy || !_confirmed) return;

    final email = _email.text.trim();

    if (email.length > 320 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _error = 'Enter a valid administrator email address.';
        _message = null;
      });

      return;
    }

    setState(() {
      _busy = true;
      _confirmed = false;
      _error = null;
      _message = null;
    });

    try {
      await widget.repository.requestRecovery(adminEmail: email);

      if (!_guard()) return;

      _email.clear();

      setState(() {
        _message = 'If eligible, secure recovery instructions will be sent.';
      });
    } catch (_) {
      if (!_guard()) return;

      setState(() {
        _error =
            'Unable to request recovery. Check your authorization and retry.';
      });
    } finally {
      if (_guard()) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final denied = _blocked || !_authorized;

    return Scaffold(
      appBar: AppBar(title: const Text('Administrator MFA recovery')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (denied)
                    const Text(
                      'Recovery permission is required.',
                      key: ValueKey('admin-recovery-denied'),
                    )
                  else ...[
                    const Icon(Icons.admin_panel_settings_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Request secure MFA recovery',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Request recovery only for an authorized '
                      'administrator who has lost authenticator access.',
                    ),
                    const SizedBox(height: 20),
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          key: const ValueKey('admin-recovery-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _message!,
                          key: const ValueKey('admin-recovery-success'),
                        ),
                      ),
                    TextField(
                      key: const ValueKey('admin-recovery-email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Target administrator email',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (!_guard()) return;

                        setState(() {
                          _confirmed = false;
                          _error = null;
                          _message = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      key: const ValueKey('admin-recovery-confirm'),
                      contentPadding: EdgeInsets.zero,
                      value: _confirmed,
                      onChanged:
                          _busy
                              ? null
                              : (value) {
                                if (!_guard()) return;

                                setState(() {
                                  _confirmed = value ?? false;
                                });
                              },
                      title: const Text(
                        'I confirm this recovery request is authorized.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey('admin-recovery-submit'),
                      onPressed: _busy || !_confirmed ? null : _submit,
                      child: const Text('Request MFA recovery'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Recovery does not bypass administrator MFA. '
                      'The recipient must complete secure enrollment.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionGuard.cancel();
    _email.dispose();

    super.dispose();
  }
}
