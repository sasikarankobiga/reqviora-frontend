import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../application/auth_providers.dart';
import '../domain/auth_error_message.dart';
import '../domain/auth_validation.dart';

class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({
    super.key,
    this.confirmChange = false,
    this.token = '',
  });

  final bool confirmChange;
  final String token;

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  bool _busy = false;
  bool _confirmed = false;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _profile;
  int _generation = authSession.generation;

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) return;

    _generation = authSession.generation;

    if (widget.confirmChange) return;

    _email.clear();

    setState(() {
      _profile = null;
      _error = null;
      _notice = null;
      _busy = false;
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_busy || !authSession.authenticated) return;

    setState(() {
      _busy = true;
      _error = null;
      _profile = null;
    });

    final generation = authSession.generation;

    try {
      final result = await ref.read(authRepositoryProvider).getProfile();

      if (!mounted || generation != authSession.generation) return;

      setState(() => _profile = result);
    } catch (error) {
      if (mounted && generation == authSession.generation) {
        setState(() => _error = authErrorMessage(error));
      }
    } finally {
      if (mounted && generation == authSession.generation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || _confirmed) return;

    if (!widget.confirmChange && !authSession.authenticated) {
      return;
    }

    final generation = authSession.generation;

    if (!widget.confirmChange && !(_form.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);

      if (widget.confirmChange) {
        await repository.confirmEmailChange(widget.token);

        if (!mounted) return;

        setState(() {
          _confirmed = true;
          _notice = 'Email changed. Sign in with your new email address.';
        });
      } else {
        await repository.requestEmailChange(_email.text);

        if (!mounted || generation != authSession.generation) return;

        setState(() {
          _notice =
              'Confirmation request accepted. Check your new email '
              'address for the confirmation link.';
        });
      }
    } catch (error) {
      if (mounted &&
          (widget.confirmChange || generation == authSession.generation)) {
        setState(() => _error = authErrorMessage(error));
      }
    } finally {
      if (mounted &&
          (widget.confirmChange || generation == authSession.generation)) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.confirmChange ? 'Confirm email change' : 'My account',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.confirmChange
                            ? 'Confirm your new email address'
                            : 'Account profile',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (!widget.confirmChange) ...[
                        if (authSession.authenticated) ...[
                          OutlinedButton.icon(
                            onPressed:
                                _busy
                                    ? null
                                    : () => context.push('/administration'),
                            icon: const Icon(Icons.admin_panel_settings),
                            label: const LocalizedUiText('Administration'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        OutlinedButton.icon(
                          onPressed:
                              _busy || !authSession.authenticated
                                  ? null
                                  : _loadProfile,
                          icon: const Icon(Icons.refresh),
                          label: const LocalizedUiText('Load account profile'),
                        ),
                        if (_profile != null) ...[
                          const SizedBox(height: 12),
                          if (_profile!['displayName'] is String)
                            Text(_profile!['displayName'] as String),
                          if (_profile!['email'] is String)
                            Text(_profile!['email'] as String),
                        ],
                        const Divider(height: 32),
                        const LocalizedUiText('Change email address'),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('account-new-email'),
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidation.validateEmail,
                          decoration: InputDecoration(
                            labelText: uiText(
                              context,
                              'New email address',
                              'புதிய மின்னஞ்சல் முகவரி',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your email will only change after you confirm '
                          'the secure link sent to your new address.',
                        ),
                      ] else
                        Text(
                          widget.token.isEmpty
                              ? 'Open the confirmation link from your email.'
                              : 'Confirm the requested email change.',
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const ValueKey('account-email-submit'),
                        onPressed:
                            _busy ||
                                    _confirmed ||
                                    (widget.confirmChange &&
                                        widget.token.isEmpty)
                                ? null
                                : _submit,
                        child: Text(
                          _busy
                              ? 'Processing...'
                              : widget.confirmChange
                              ? 'Confirm email change'
                              : 'Request email change',
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      if (_notice != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(_notice!),
                          ),
                        ),
                      TextButton(
                        onPressed:
                            _busy
                                ? null
                                : () => context.go(
                                  authSession.authenticated
                                      ? '/projects'
                                      : '/login',
                                ),
                        child: const LocalizedUiText('Return to REQVIORA'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
