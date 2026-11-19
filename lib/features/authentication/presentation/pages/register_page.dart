import 'package:flutter/material.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_form_field.dart';

typedef RegisterSubmit = Future<void> Function(
  String email,
  String password,
);

/// Registration fields and policies are provisional.
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.onSubmit,
    this.onShowLogin,
    this.authError,
    this.isOffline = false,
  });

  final RegisterSubmit? onSubmit;
  final VoidCallback? onShowLogin;
  final String? authError;
  final bool isOffline;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  bool _showPassword = false;
  String? _localError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || widget.isOffline || widget.onSubmit == null) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _localError = null;
    });

    try {
      await widget.onSubmit!(_email.text.trim(), _password.text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _localError = 'Account creation could not be completed.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _submitting || widget.isOffline;

    return AuthShell(
      isRegister: true,
      onShowLogin: widget.onShowLogin,
      title: 'Create your account',
      subtitle: 'Start with the essentials.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isOffline)
              const _Notice(
                key: Key('register-offline'),
                message: 'You are offline. Reconnect to register.',
              ),
            if (_localError != null || widget.authError != null)
              _Notice(
                key: const Key('register-error'),
                message: _localError ?? widget.authError!,
              ),
            AuthFormField(
              label: 'Email address',
              controller: _email,
              validator: AuthFieldValidation.email,
              keyboardType: TextInputType.emailAddress,
              enabled: !disabled,
            ),
            const SizedBox(height: 16),
            AuthFormField(
              label: 'Password',
              controller: _password,
              validator: AuthFieldValidation.password,
              obscureText: !_showPassword,
              enabled: !disabled,
              suffixIcon: IconButton(
                tooltip: _showPassword
                    ? 'Hide password'
                    : 'Show password',
                onPressed: disabled
                    ? null
                    : () => setState(() {
                          _showPassword = !_showPassword;
                        }),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthFormField(
              label: 'Confirm password',
              controller: _confirm,
              obscureText: !_showPassword,
              enabled: !disabled,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password.';
                }
                if (value != _password.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Password policy pending backend confirmation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('register-submit'),
              onPressed: disabled || widget.onSubmit == null
                  ? null
                  : _submit,
              child: _submitting
                  ? const Text('Creating account...')
                  : const Text('Create account'),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Already have an account?'),
                TextButton(
                  onPressed: disabled ? null : widget.onShowLogin,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Text(message),
        ),
      ),
    );
  }
}
