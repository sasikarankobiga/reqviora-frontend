import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../application/auth_providers.dart';
import '../domain/auth_error_message.dart';
import '../../../l10n/app_localizations.dart';

enum AccountAction { forgotPassword, resetPassword, verifyEmail, setupMfa }

/// Real REST-backed recovery, verification and MFA onboarding screens.
/// This does not fake successful email delivery or MFA enablement.
class AccountSecurityPage extends ConsumerStatefulWidget {
  const AccountSecurityPage({super.key, required this.action, this.token = ''});

  final AccountAction action;
  final String token;

  @override
  ConsumerState<AccountSecurityPage> createState() =>
      _AccountSecurityPageState();
}

class _AccountSecurityPageState extends ConsumerState<AccountSecurityPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _mfaProvision;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();
    super.dispose();
  }

  String _title(AppLocalizations l10n) => switch (widget.action) {
    AccountAction.forgotPassword => l10n.forgotPassword,
    AccountAction.resetPassword => l10n.resetPassword,
    AccountAction.verifyEmail => l10n.verifyEmail,
    AccountAction.setupMfa => l10n.mfaSetup,
  };

  String _description(AppLocalizations l10n) => switch (widget.action) {
    AccountAction.forgotPassword => l10n.forgotPasswordDescription,
    AccountAction.resetPassword =>
      'Choose a new password using the emailed link.',
    AccountAction.verifyEmail =>
      'Confirm your address with a one-time email token.',
    AccountAction.setupMfa =>
      'Add an authenticator app to protect your account.',
  };

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      switch (widget.action) {
        case AccountAction.forgotPassword:
          await repository.forgotPassword(_email.text.trim());
          _notice =
              'If the account exists, a password reset link will be sent.';
          break;
        case AccountAction.resetPassword:
          if (widget.token.isEmpty) throw StateError('Missing reset token');
          await repository.resetPassword(widget.token, _password.text);
          _notice = 'Password changed. Sign in using your new password.';
          break;
        case AccountAction.verifyEmail:
          if (widget.token.isNotEmpty) {
            await repository.confirmEmailVerification(widget.token);
            _notice = 'Email address successfully verified.';
          } else {
            if (!authSession.authenticated) {
              throw StateError('Sign in to request a verification email.');
            }
            await repository.requestEmailVerification();
            _notice =
                'If verification is pending, a link will be emailed to you.';
          }
          break;
        case AccountAction.setupMfa:
          if (_mfaProvision == null) {
            _mfaProvision = await repository.provisionMfa();
            _notice =
                'Scan the authenticator URI or enter the secret. Store recovery codes safely before confirming.';
          } else {
            await repository.verifyMfa(_otp.text.trim());
            _notice =
                'MFA verified and enabled. Store your recovery codes before leaving.';
          }
          break;
      }
    } catch (error) {
      _error = authErrorMessage(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final action = widget.action;
    final requiresLink =
        action == AccountAction.resetPassword && widget.token.isEmpty;
    final isMfa = action == AccountAction.setupMfa;
    final requiresSignIn =
        (isMfa ||
            (action == AccountAction.verifyEmail && widget.token.isEmpty)) &&
        !authSession.authenticated;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountSecurity)),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title(l10n),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(_description(l10n)),
                      const SizedBox(height: 20),
                      if (requiresLink)
                        const Text(
                          'Open the secure link from your email to reset your password.',
                        ),
                      if (requiresSignIn)
                        const Text(
                          'Sign in before using this protected operation.',
                        ),
                      if (action == AccountAction.forgotPassword)
                        TextFormField(
                          key: const ValueKey('security-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: l10n.accountEmail,
                          ),
                          validator:
                              (value) =>
                                  value != null &&
                                          value.contains('@') &&
                                          value.contains('.')
                                      ? null
                                      : 'Enter a valid email address',
                        ),
                      if (action == AccountAction.resetPassword &&
                          !requiresLink) ...[
                        TextFormField(
                          key: const ValueKey('security-password'),
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                          validator:
                              (value) =>
                                  (value?.length ?? 0) >= 12
                                      ? null
                                      : 'Use at least 12 characters',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('security-confirm-password'),
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                          ),
                          validator:
                              (value) =>
                                  value == _password.text
                                      ? null
                                      : 'Passwords do not match',
                        ),
                      ],
                      if (isMfa && _mfaProvision != null) ...[
                        const SizedBox(height: 12),
                        const Text('Authenticator setup URI (private):'),
                        SelectableText(
                          (_mfaProvision!['uri'] ?? '').toString(),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Recovery codes — store offline and never share:',
                        ),
                        for (final code
                            in (_mfaProvision!['recoveryCodes'] as List? ?? []))
                          SelectableText(code.toString()),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('security-otp'),
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '6-digit authenticator code',
                          ),
                          validator:
                              (value) =>
                                  RegExp(
                                        r'^\d{6}$',
                                      ).hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'Enter a 6-digit code',
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 16),
                        Semantics(liveRegion: true, child: Text(_notice!)),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed:
                            (_busy || requiresLink || requiresSignIn)
                                ? null
                                : _submit,
                        child: Text(
                          _busy
                              ? 'Processing…'
                              : switch (action) {
                                AccountAction.forgotPassword =>
                                  l10n.sendResetLink,
                                AccountAction.resetPassword => 'Reset password',
                                AccountAction.verifyEmail =>
                                  widget.token.isEmpty
                                      ? 'Request verification email'
                                      : 'Confirm email',
                                AccountAction.setupMfa =>
                                  _mfaProvision == null
                                      ? 'Start MFA setup'
                                      : 'Verify authenticator',
                              },
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => context.go(
                              authSession.authenticated
                                  ? '/projects'
                                  : '/login',
                            ),
                        child: Text(l10n.returnToReqviora),
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
