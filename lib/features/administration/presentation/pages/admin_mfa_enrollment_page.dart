import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../data/repositories/admin_mfa_repository.dart';

/// Dedicated signed-out enrollment UI for administrator MFA.
/// This page must not replace normal account MFA or admin login MFA.
class AdminMfaEnrollmentPage extends StatefulWidget {
  const AdminMfaEnrollmentPage({
    super.key,
    required this.repository,
    required this.onReturnToSignIn,
  });

  final AdminMfaRepository repository;
  final VoidCallback onReturnToSignIn;

  @override
  State<AdminMfaEnrollmentPage> createState() => _AdminMfaEnrollmentPageState();
}

class _AdminMfaEnrollmentPageState extends State<AdminMfaEnrollmentPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _token = TextEditingController();
  final _code = TextEditingController();

  late final int _sessionGeneration;
  late final Timer _sessionGuard;

  AdminMfaProvision? _provision;
  String? _credential;
  String? _message;
  String? _error;

  bool _busy = false;
  bool _savedCodes = false;
  bool _verified = false;
  bool _blocked = false;

  bool get _validSession =>
      !authSession.authenticated &&
      authSession.generation == _sessionGeneration;

  @override
  void initState() {
    super.initState();

    _sessionGeneration = authSession.generation;
    _blocked = authSession.authenticated;

    _sessionGuard = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && !_validSession && !_blocked) {
        _invalidate();
      }
    });
  }

  void _clearSensitiveData() {
    _email.clear();
    _password.clear();
    _token.clear();
    _code.clear();

    _credential = null;
    _provision = null;
    _savedCodes = false;
  }

  void _invalidate() {
    if (!mounted) return;

    _clearSensitiveData();

    setState(() {
      _busy = false;
      _blocked = true;
      _verified = false;
      _message = null;
      _error = null;
    });
  }

  bool _guard() {
    if (!mounted || _blocked) return false;

    if (!_validSession) {
      _invalidate();
      return false;
    }

    return true;
  }

  void _startRequest() {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
  }

  Future<void> _requestBootstrap() async {
    if (!_guard() || _busy || _provision != null || _verified) return;

    final email = _email.text.trim();
    final password = _password.text;

    _startRequest();
    _password.clear();

    try {
      await widget.repository.requestBootstrap(
        email: email,
        password: password,
      );

      if (!_guard()) return;

      setState(() {
        _message =
            'If eligible, enrollment instructions will be sent securely.';
      });
    } catch (_) {
      if (!_guard()) return;

      setState(() {
        _error = 'Unable to request enrollment. Check your details and retry.';
      });
    } finally {
      if (_guard()) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _requestProvision() async {
    if (!_guard() || _busy || _provision != null || _verified) return;

    final credential = _token.text;

    _startRequest();
    _token.clear();
    _password.clear();

    try {
      final result = await widget.repository.provision(token: credential);

      if (!_guard()) return;

      setState(() {
        _credential = credential;
        _provision = result;
        _savedCodes = false;
        _email.clear();
      });
    } catch (_) {
      if (!_guard()) return;

      setState(() {
        _error = 'Unable to provision MFA. Check your enrollment credential.';
      });
    } finally {
      if (_guard()) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verify() async {
    if (!_guard() || _busy || !_savedCodes || _verified) return;

    final credential = _credential;

    if (credential == null || _provision == null) return;

    final code = _code.text;

    _startRequest();
    _code.clear();

    try {
      await widget.repository.verify(token: credential, code: code);

      if (!_guard()) return;

      _clearSensitiveData();

      setState(() {
        _verified = true;
        _message = 'Administrator MFA verification completed.';
      });
    } catch (_) {
      if (!_guard()) return;

      setState(() {
        _error = 'Verification failed. Check the authenticator code and retry.';
      });
    } finally {
      if (_guard()) {
        setState(() => _busy = false);
      }
    }
  }

  void _returnToSignIn() {
    if (_busy) return;

    _invalidate();
    widget.onReturnToSignIn();
  }

  Widget _field({
    required String id,
    required String label,
    required TextEditingController controller,
    bool secret = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey(id),
        controller: controller,
        enabled: !_busy,
        obscureText: secret,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  List<Widget> _initialContent() {
    return [
      const Text(
        'Request administrator MFA enrollment',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      _field(
        id: 'admin-enrollment-email',
        label: 'Administrator email',
        controller: _email,
        keyboardType: TextInputType.emailAddress,
      ),
      _field(
        id: 'admin-enrollment-password',
        label: 'Password',
        controller: _password,
        secret: true,
      ),
      FilledButton(
        key: const ValueKey('admin-bootstrap-request'),
        onPressed: _busy ? null : _requestBootstrap,
        child: const Text('Request enrollment'),
      ),
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 12),
      const Text(
        'Already received an enrollment credential?',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      _field(
        id: 'admin-enrollment-token',
        label: 'Enrollment credential',
        controller: _token,
        secret: true,
      ),
      FilledButton(
        key: const ValueKey('admin-provision-request'),
        onPressed: _busy ? null : _requestProvision,
        child: const Text('Set up authenticator'),
      ),
    ];
  }

  List<Widget> _provisionContent(AdminMfaProvision provision) {
    return [
      const Text('Add the setup key to your authenticator app.'),
      const SizedBox(height: 8),
      const Text('Account: REQVIORA administrator'),
      const SizedBox(height: 12),
      const Text('Private authenticator setup key'),
      SelectableText(
        provision.secret,
        key: const ValueKey('admin-enrollment-secret'),
      ),
      const SizedBox(height: 20),
      const Text(
        'Recovery codes — store securely offline.',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text('Never share these codes or your setup key.'),
      const SizedBox(height: 8),
      SelectableText(
        provision.recoveryCodes.join('\n'),
        key: const ValueKey('admin-enrollment-recovery-codes'),
      ),
      CheckboxListTile(
        key: const ValueKey('admin-recovery-confirmation'),
        contentPadding: EdgeInsets.zero,
        value: _savedCodes,
        onChanged:
            _busy
                ? null
                : (value) {
                  if (!_guard()) return;
                  setState(() => _savedCodes = value ?? false);
                },
        title: const Text('I have securely saved my recovery codes.'),
      ),
      _field(
        id: 'admin-enrollment-code',
        label: 'Six-digit authenticator code',
        controller: _code,
        keyboardType: TextInputType.number,
        secret: true,
      ),
      FilledButton(
        key: const ValueKey('admin-enrollment-verify'),
        onPressed: _busy || !_savedCodes ? null : _verify,
        child: const Text('Verify administrator MFA'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked || !_validSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator MFA setup'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (blocked)
                  const Text('The session changed. Return to sign in.')
                else ...[
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_message!),
                    ),
                  if (_verified)
                    const Text(
                      'Sign in again using your administrator credentials.',
                    )
                  else if (_provision != null)
                    ..._provisionContent(_provision!)
                  else
                    ..._initialContent(),
                ],
                const SizedBox(height: 20),
                OutlinedButton(
                  key: const ValueKey('admin-enrollment-return'),
                  onPressed: _busy && !blocked ? null : _returnToSignIn,
                  child: const Text('Return to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sessionGuard.cancel();

    _credential = null;
    _provision = null;

    _email.dispose();
    _password.dispose();
    _token.dispose();
    _code.dispose();

    super.dispose();
  }
}
