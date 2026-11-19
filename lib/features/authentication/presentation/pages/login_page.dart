import 'package:flutter/material.dart';
import '../widgets/auth_shell.dart';
import '../widgets/auth_form_field.dart';

typedef LoginSubmit = Future<void> Function(
  String email,
  String password,
);

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.onSubmit,
    this.onShowRegister,
    this.onForgotPassword,
    this.authError,
    this.isOffline = false,
  });

  final LoginSubmit? onSubmit;
  final VoidCallback? onShowRegister;
  final VoidCallback? onForgotPassword;
  final String? authError;
  final bool isOffline;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _showPassword = false;
  String? _localError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
          _localError = 'Sign in could not be completed. Try again.';
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
      isRegister: false,
      onShowRegister: widget.onShowRegister,
      title: 'Welcome back',
      subtitle: 'Sign in to continue your work.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isOffline)
              const _Notice(
                key: Key('login-offline'),
                message: 'You are offline. Reconnect to sign in.',
              ),
            if (_localError != null || widget.authError != null)
              _Notice(
                key: const Key('login-error'),
                message: _localError ?? widget.authError!,
              ),
            AuthFormField(
              label: 'Email address',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: AuthFieldValidation.email,
              enabled: !disabled,
            ),
            const SizedBox(height: 16),
            AuthFormField(
              label: 'Password',
              controller: _password,
              obscureText: !_showPassword,
              validator: AuthFieldValidation.password,
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: disabled ? null : widget.onForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('login-submit'),
              onPressed: disabled || widget.onSubmit == null
                  ? null
                  : _submit,
              child: _submitting
                  ? const Text('Signing in...')
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('New to REQVIORA?'),
                TextButton(
                  onPressed: disabled ? null : widget.onShowRegister,
                  child: const Text('Create an account'),
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
