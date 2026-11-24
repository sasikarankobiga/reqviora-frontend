import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import '../domain/auth_error_message.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final formKey = GlobalKey<FormState>();

  final displayNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isRegister = false;
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  String? errorMessage;
  String? successMessage;

  @override
  void dispose() {
    displayNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void switchMode() {
    if (isLoading) return;

    setState(() {
      isRegister = !isRegister;
      errorMessage = null;
      successMessage = null;

      displayNameController.clear();
      passwordController.clear();
      confirmPasswordController.clear();

      showPassword = false;
      showConfirmPassword = false;
    });

    formKey.currentState?.reset();
  }

  Future<void> submitForm() async {
    if (isLoading) return;

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);

      if (isRegister) {
        await repository.registerAccount(
          emailController.text.trim(),
          passwordController.text,
          displayNameController.text.trim(),
        );

        if (!mounted) return;

        setState(() {
          isRegister = false;

          displayNameController.clear();
          passwordController.clear();
          confirmPasswordController.clear();

          successMessage =
              'Registration request completed. '
              'Your account may require email verification '
              'before you can sign in. '
              'Please follow the instructions from your '
              'account service.';
        });
      } else {
        await repository.signIn(
          emailController.text.trim(),
          passwordController.text,
        );

        if (!mounted) return;

        context.go('/projects');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = authErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildBrandPanel() {
    return Container(
      height: 520,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF292051), Color(0xFF725AE5)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 42),
          SizedBox(height: 24),
          Text(
            'REQVIORA',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'From Requirements to Reality',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Spacer(),
          Text(
            'Capture requirements.\n'
            'Design user experiences.\n'
            'Build your project Second Brain.',
            style: TextStyle(fontSize: 15, height: 1.7, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget buildAuthForm(BuildContext context) {
    return SurfaceCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isRegister ? 'Create your account' : 'Welcome back',
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 8),

            const Text(
              'Secure access to your REQVIORA workspace',
              style: TextStyle(color: AppColors.muted),
            ),

            const SizedBox(height: 24),

            // Display Name is required only for registration.
            if (isRegister) ...[
              TextFormField(
                key: const ValueKey('auth-display-name'),
                controller: displayNameController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final name = (value ?? '').trim();

                  if (name.isEmpty) {
                    return 'Display name is required';
                  }

                  if (name.length < 2) {
                    return 'Display name must contain at least 2 characters';
                  }

                  if (name.length > 200) {
                    return 'Display name must not exceed 200 characters';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Email field.
            TextFormField(
              key: const ValueKey('auth-email'),
              controller: emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: AuthValidation.validateEmail,
            ),

            const SizedBox(height: 16),

            // Password field.
            TextFormField(
              key: const ValueKey('auth-password'),
              controller: passwordController,
              enabled: !isLoading,
              obscureText: !showPassword,
              autofillHints:
                  isRegister
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Hide password' : 'Show password',
                  onPressed:
                      isLoading
                          ? null
                          : () {
                            setState(() {
                              showPassword = !showPassword;
                            });
                          },
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: AuthValidation.validatePassword,
            ),

            // Confirm password is visible only in registration.
            if (isRegister) ...[
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('auth-confirm-password'),
                controller: confirmPasswordController,
                enabled: !isLoading,
                obscureText: !showConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    tooltip:
                        showConfirmPassword
                            ? 'Hide confirm password'
                            : 'Show confirm password',
                    onPressed:
                        isLoading
                            ? null
                            : () {
                              setState(() {
                                showConfirmPassword = !showConfirmPassword;
                              });
                            },
                    icon: Icon(
                      showConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  return AuthValidation.validateConfirmPassword(
                    value,
                    passwordController.text,
                  );
                },
              ),

              const SizedBox(height: 10),

              const Text(
                'Use at least 12 characters for your password.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],

            const SizedBox(height: 24),

            // Submit button.
            FilledButton(
              key: const ValueKey('auth-submit'),
              onPressed: isLoading ? null : submitForm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(isRegister ? 'Create Account' : 'Sign In'),
              ),
            ),

            const SizedBox(height: 14),

            // Switch Login / Registration mode.
            TextButton(
              key: const ValueKey('auth-switch-mode'),
              onPressed: isLoading ? null : switchMode,
              child: Text(
                isRegister
                    ? 'Already have an account? Sign in'
                    : 'New to REQVIORA? Register',
              ),
            ),

            // API / validation errors.
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              InlineError(errorMessage!),
            ],

            // Success message after registration.
            if (successMessage != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    successMessage!,
                    style: const TextStyle(color: Color(0xFF23663A)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            const Text(
              'Authentication uses the ASP.NET Core backend. '
              'Email verification and password recovery '
              'depend on backend support.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 850;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child:
                isDesktop
                    ? Row(
                      children: [
                        Expanded(child: buildBrandPanel()),
                        const SizedBox(width: 26),
                        Expanded(child: buildAuthForm(context)),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'REQVIORA',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        buildAuthForm(context),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
