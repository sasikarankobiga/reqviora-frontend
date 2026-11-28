import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/api_client.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validation.dart';
import '../domain/auth_error_message.dart';
import '../../../l10n/language_settings.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({
    super.key,
    this.register = false,
    this.showRegistrationSuccess = false,
    this.postSignInPath,
  });

  final bool register;
  final bool showRegistrationSuccess;
  final String? postSignInPath;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final formKey = GlobalKey<FormState>();

  final displayNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final otpController = TextEditingController();

  late bool isRegister;

  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool showAuthenticatorCode = false;

  String? errorMessage;
  String? successMessage;
  bool registrationComplete = false;

  @override
  void initState() {
    super.initState();

    isRegister = widget.register;

    if (widget.showRegistrationSuccess) {
      successMessage =
          'Registration completed. Check your email for a '
          'verification link before signing in.';
    }
  }

  @override
  void dispose() {
    displayNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();

    super.dispose();
  }

  void switchMode() {
    if (isLoading) return;

    context.go(isRegister ? '/login' : '/register');
  }

  Future<void> submitForm() async {
    if (isLoading || registrationComplete) return;

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
        final result = await repository.registerAccount(
          emailController.text.trim(),
          passwordController.text,
          displayNameController.text.trim(),
        );

        if (!mounted) return;

        passwordController.clear();
        confirmPasswordController.clear();
        final registrationNotice =
            result.verificationEmailSent
                ? uiText(
                  context,
                  'Account created. A verification email was requested. '
                      'Check your inbox and spam folder before signing in.',
                  'கணக்கு உருவாக்கப்பட்டது. உறுதிப்படுத்தல் மின்னஞ்சல் '
                      'கோரப்பட்டது. உள்நுழைவதற்கு முன் உங்கள் அஞ்சல் மற்றும் '
                      'தேவையற்ற அஞ்சல் கோப்புறையைச் சரிபார்க்கவும்.',
                )
                : uiText(
                  context,
                  'Account created, but the email service could not accept '
                      'the verification message. Use the resend form; do not '
                      'register again.',
                  'கணக்கு உருவாக்கப்பட்டது, ஆனால் மின்னஞ்சல் சேவையால் '
                      'உறுதிப்படுத்தல் செய்தியை ஏற்க முடியவில்லை. மீண்டும் '
                      'அனுப்பும் படிவத்தைப் பயன்படுத்தவும்; மீண்டும் பதிவு '
                      'செய்ய வேண்டாம்.',
                );
        setState(() {
          registrationComplete = true;
          successMessage = registrationNotice;
        });
      } else {
        await repository.signIn(
          emailController.text.trim(),
          passwordController.text,
          otpCode: showAuthenticatorCode ? otpController.text.trim() : null,
        );

        if (!mounted) return;

        context.go(widget.postSignInPath ?? '/projects');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        if (!isRegister &&
            e is ApiException &&
            e.statusCode == 401 &&
            (e.message == 'One-time password required.' ||
                e.message == 'One-time password required. (HTTP 401)')) {
          showAuthenticatorCode = true;
        }

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
              isRegister
                  ? uiText(
                    context,
                    'Create your account',
                    'உங்கள் கணக்கை உருவாக்குங்கள்',
                  )
                  : uiText(context, 'Welcome back', 'மீண்டும் வரவேற்கிறோம்'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 8),

            const Align(
              alignment: Alignment.centerRight,
              child: LanguageSwitcher(),
            ),

            Text(
              uiText(
                context,
                'Secure access to your REQVIORA workspace',
                'உங்கள் REQVIORA பணியிடத்திற்கான பாதுகாப்பான அணுகல்',
              ),
              style: const TextStyle(color: AppColors.muted),
            ),

            const SizedBox(height: 24),

            // Display Name is required only for registration.
            if (isRegister) ...[
              TextFormField(
                key: const ValueKey('auth-display-name'),
                controller: displayNameController,
                enabled: !isLoading && !registrationComplete,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: InputDecoration(
                  labelText: uiText(context, 'Display Name', 'பயனர் பெயர்'),
                  hintText: uiText(
                    context,
                    'Enter your full name',
                    'உங்கள் முழுப் பெயரை உள்ளிடவும்',
                  ),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final name = (value ?? '').trim();

                  if (name.isEmpty) {
                    return uiText(
                      context,
                      'Display name is required',
                      'பயனர் பெயர் அவசியம்',
                    );
                  }

                  if (name.length < 2) {
                    return uiText(
                      context,
                      'Display name must contain at least 2 characters',
                      'பயனர் பெயரில் குறைந்தது 2 எழுத்துகள் இருக்க வேண்டும்',
                    );
                  }

                  if (name.length > 200) {
                    return uiText(
                      context,
                      'Display name must not exceed 200 characters',
                      'பயனர் பெயர் 200 எழுத்துகளைத் தாண்டக்கூடாது',
                    );
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
              enabled: !isLoading && !registrationComplete,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  'Email Address',
                  'மின்னஞ்சல் முகவரி',
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator:
                  (value) => localizedValidation(
                    context,
                    AuthValidation.validateEmail(value),
                  ),
            ),

            const SizedBox(height: 16),

            // Password field.
            TextFormField(
              key: const ValueKey('auth-password'),
              controller: passwordController,
              enabled: !isLoading && !registrationComplete,
              obscureText: !showPassword,
              textInputAction:
                  isRegister ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: isRegister ? null : (_) => submitForm(),
              autofillHints:
                  isRegister
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: uiText(context, 'Password', 'கடவுச்சொல்'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip:
                      showPassword
                          ? uiText(
                            context,
                            'Hide password',
                            'கடவுச்சொல்லை மறைக்கவும்',
                          )
                          : uiText(
                            context,
                            'Show password',
                            'கடவுச்சொல்லைக் காட்டவும்',
                          ),
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
              validator:
                  (value) => localizedValidation(
                    context,
                    AuthValidation.validatePassword(value),
                  ),
            ),

            // Confirm password is visible only in registration.
            if (isRegister) ...[
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('auth-confirm-password'),
                controller: confirmPasswordController,
                enabled: !isLoading && !registrationComplete,
                obscureText: !showConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submitForm(),
                decoration: InputDecoration(
                  labelText: uiText(
                    context,
                    'Confirm Password',
                    'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
                  ),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    tooltip:
                        showConfirmPassword
                            ? uiText(
                              context,
                              'Hide confirm password',
                              'உறுதிப்படுத்தும் கடவுச்சொல்லை மறைக்கவும்',
                            )
                            : uiText(
                              context,
                              'Show confirm password',
                              'உறுதிப்படுத்தும் கடவுச்சொல்லைக் காட்டவும்',
                            ),
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
                  return localizedValidation(
                    context,
                    AuthValidation.validateConfirmPassword(
                      value,
                      passwordController.text,
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),

              Text(
                uiText(
                  context,
                  'Use at least 12 characters for your password.',
                  'கடவுச்சொல்லில் குறைந்தது 12 எழுத்துகளைப் பயன்படுத்தவும்.',
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],

            // Optional authenticator code toggle.
            if (!isRegister) ...[
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('auth-toggle-mfa'),
                  onPressed:
                      isLoading
                          ? null
                          : () {
                            setState(() {
                              showAuthenticatorCode = !showAuthenticatorCode;

                              if (!showAuthenticatorCode) {
                                otpController.clear();
                              }
                            });
                          },
                  icon: const Icon(Icons.security_outlined),
                  label: Text(
                    showAuthenticatorCode
                        ? uiText(
                          context,
                          'Hide authenticator code',
                          'அங்கீகாரக் குறியீட்டை மறைக்கவும்',
                        )
                        : uiText(
                          context,
                          'Use an authenticator code',
                          'அங்கீகாரக் குறியீட்டைப் பயன்படுத்தவும்',
                        ),
                  ),
                ),
              ),
            ],

            // OTP is displayed only when requested.
            if (!isRegister && showAuthenticatorCode) ...[
              const SizedBox(height: 12),

              TextFormField(
                key: const ValueKey('auth-otp'),
                controller: otpController,
                enabled: !isLoading && !registrationComplete,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: uiText(
                    context,
                    'Authenticator code',
                    'அங்கீகாரக் குறியீடு',
                  ),
                  helperText: uiText(
                    context,
                    'Enter the code from your authenticator app.',
                    'அங்கீகார செயலியிலுள்ள குறியீட்டை உள்ளிடவும்.',
                  ),
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.security_outlined),
                ),
                validator: (value) {
                  final code = (value ?? '').trim();

                  return RegExp(r'^\d{6}$').hasMatch(code)
                      ? null
                      : uiText(
                        context,
                        'Enter a valid 6-digit authenticator code',
                        'சரியான 6 இலக்க அங்கீகாரக் குறியீட்டை உள்ளிடவும்',
                      );
                },
              ),
            ],

            const SizedBox(height: 24),

            // Submit button.
            FilledButton(
              key: const ValueKey('auth-submit'),
              onPressed: isLoading || registrationComplete ? null : submitForm,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          isRegister
                              ? uiText(
                                context,
                                'Create Account',
                                'கணக்கை உருவாக்கு',
                              )
                              : uiText(context, 'Sign In', 'உள்நுழைக'),
                        ),
              ),
            ),

            const SizedBox(height: 14),

            // Switch Login / Registration mode.
            TextButton(
              key: const ValueKey('auth-switch-mode'),
              onPressed: isLoading ? null : switchMode,
              child: Text(
                isRegister
                    ? uiText(
                      context,
                      'Already have an account? Sign in',
                      'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழைக',
                    )
                    : uiText(
                      context,
                      'New to REQVIORA? Register',
                      'புதிய பயனரா? பதிவு செய்யுங்கள்',
                    ),
              ),
            ),

            if (!isRegister) ...[
              TextButton(
                onPressed:
                    isLoading ? null : () => context.go('/forgot-password'),
                child: Text(
                  uiText(
                    context,
                    'Forgot password?',
                    'கடவுச்சொல் மறந்துவிட்டதா?',
                  ),
                ),
              ),

              TextButton(
                onPressed: isLoading ? null : () => context.go('/verify-email'),
                child: Text(
                  uiText(
                    context,
                    'Request email verification',
                    'மின்னஞ்சல் உறுதிப்படுத்தல் கோருக',
                  ),
                ),
              ),
            ],

            // API / validation errors.
            if (errorMessage != null) ...[
              const SizedBox(height: 12),

              Semantics(liveRegion: true, child: InlineError(errorMessage!)),

              if (isRegister && !registrationComplete) ...[
                const SizedBox(height: 8),

                const Text(
                  'If account creation was interrupted, check your email '
                  'before submitting again.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
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

              if (registrationComplete) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('registration-resend-link'),
                  onPressed:
                      isLoading ? null : () => context.go('/verify-email'),
                  child: Text(
                    uiText(
                      context,
                      'Resend verification email',
                      'உறுதிப்படுத்தல் மின்னஞ்சலை மீண்டும் அனுப்புக',
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('registration-login-link'),
                  onPressed: isLoading ? null : () => context.go('/login'),
                  child: Text(
                    uiText(
                      context,
                      'Continue to sign in',
                      'உள்நுழைவுக்குத் தொடரவும்',
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 18),

            Text(
              uiText(
                context,
                'Authentication uses the ASP.NET Core backend. '
                    'Email verification and password recovery '
                    'depend on backend support.',
                'உள்நுழைவு ASP.NET Core பின்தளத்தைப் பயன்படுத்துகிறது. '
                    'மின்னஞ்சல் உறுதிப்படுத்தல் மற்றும் கடவுச்சொல் மீட்டமைப்பு '
                    'பின்தள சேவையைச் சார்ந்தவை.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(width < 480 ? 12 : 24),
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
