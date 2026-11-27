import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/language_settings.dart';
import '../../../core/auth/auth_session.dart';
import '../application/auth_providers.dart';
import '../domain/auth_error_message.dart';

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
  bool _mfaCompleted = false;

  String? _error;
  String? _notice;

  Map<String, dynamic>? _mfaProvision;

  int _generation = authSession.generation;

  bool get _protectedAction =>
      widget.action == AccountAction.setupMfa ||
      (widget.action == AccountAction.verifyEmail && widget.token.isEmpty);

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;

    if (!_protectedAction) return;

    _otp.clear();

    setState(() {
      _mfaProvision = null;
      _mfaCompleted = false;
      _busy = false;
      _error = null;
      _notice = null;
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);

    _mfaProvision = null;

    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _otp.dispose();

    super.dispose();
  }

  String get _title => switch (widget.action) {
    AccountAction.forgotPassword => uiText(
      context,
      'Forgot password',
      'கடவுச்சொல்லை மறந்துவிட்டீர்களா',
    ),
    AccountAction.resetPassword => uiText(
      context,
      'Reset password',
      'கடவுச்சொல்லை மீட்டமைக்கவும்',
    ),
    AccountAction.verifyEmail => uiText(
      context,
      'Verify your email',
      'மின்னஞ்சலை உறுதிப்படுத்துங்கள்',
    ),
    AccountAction.setupMfa => uiText(
      context,
      'Authenticator setup',
      'அங்கீகார அமைப்பு',
    ),
  };

  String get _description => switch (widget.action) {
    AccountAction.forgotPassword => uiText(
      context,
      'Request a secure password-reset link.',
      'பாதுகாப்பான கடவுச்சொல் மீட்டமைப்பு இணைப்பைக் கோருங்கள்.',
    ),
    AccountAction.resetPassword => uiText(
      context,
      'Choose a new password using the emailed link.',
      'மின்னஞ்சலில் கிடைத்த இணைப்பைப் பயன்படுத்திப் புதிய கடவுச்சொல்லை அமைக்கவும்.',
    ),
    AccountAction.verifyEmail => uiText(
      context,
      'Confirm your address with a one-time email token.',
      'ஒருமுறை பயன்படுத்தும் மின்னஞ்சல் குறியீட்டின் மூலம் உங்கள் முகவரியை உறுதிப்படுத்துங்கள்.',
    ),
    AccountAction.setupMfa => uiText(
      context,
      'Add an authenticator app to protect your account.',
      'உங்கள் கணக்கைப் பாதுகாக்க அங்கீகார செயலியைச் சேர்க்கவும்.',
    ),
  };

  Future<void> _submit() async {
    if (_protectedAction && !authSession.authenticated) {
      return;
    }

    final generation = authSession.generation;

    if (_busy || _mfaCompleted || !(_form.currentState?.validate() ?? false)) {
      return;
    }

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

          if (!mounted) return;

          _notice = uiText(
            context,
            'If the account exists, a password reset link will be sent.',
            'கணக்கு இருந்தால் கடவுச்சொல் மீட்டமைப்பு இணைப்பு அனுப்பப்படும்.',
          );

          break;

        case AccountAction.resetPassword:
          if (widget.token.isEmpty) {
            throw StateError('Missing reset token');
          }

          await repository.resetPassword(widget.token, _password.text);

          if (!mounted) return;

          _password.clear();
          _confirm.clear();

          _notice = uiText(
            context,
            'Password changed. Sign in using your new password.',
            'கடவுச்சொல் மாற்றப்பட்டது. புதிய கடவுச்சொல்லைப் பயன்படுத்தி உள்நுழையவும்.',
          );

          break;

        case AccountAction.verifyEmail:
          if (widget.token.isNotEmpty) {
            await repository.confirmEmailVerification(widget.token);

            if (!mounted) return;

            _notice = uiText(
              context,
              'Email address successfully verified.',
              'மின்னஞ்சல் முகவரி வெற்றிகரமாக உறுதிப்படுத்தப்பட்டது.',
            );
          } else {
            if (!authSession.authenticated) {
              throw StateError('Sign in to request a verification email.');
            }

            await repository.requestEmailVerification();

            if (!mounted || generation != authSession.generation) {
              return;
            }

            _notice = uiText(
              context,
              'If verification is pending, a link will be emailed to you.',
              'உறுதிப்படுத்தல் நிலுவையில் இருந்தால் மின்னஞ்சல் இணைப்பு அனுப்பப்படும்.',
            );
          }

          break;

        case AccountAction.setupMfa:
          if (_mfaProvision == null) {
            final provision = await repository.provisionMfa();

            if (!mounted || generation != authSession.generation) {
              return;
            }

            final uri = provision['uri'];
            final recovery = provision['recoveryCodes'];

            final parsedUri = uri is String ? Uri.tryParse(uri) : null;

            // AuthRepository may return only the URI and
            // recovery codes. Obtain the secret from the URI
            // when a separate secret field is unavailable.
            final uriSecret = parsedUri?.queryParameters['secret'];

            final secret = provision['secret'] ?? uriSecret;

            if (secret is! String ||
                !RegExp(r'^[A-Z2-7]+$').hasMatch(secret) ||
                parsedUri == null ||
                parsedUri.scheme != 'otpauth' ||
                parsedUri.host != 'totp' ||
                uriSecret != secret ||
                recovery is! List ||
                recovery.isEmpty ||
                recovery.any(
                  (code) => code is! String || code.trim().isEmpty,
                )) {
              throw const FormatException('Invalid MFA setup response');
            }

            _mfaProvision = {
              'secret': secret,
              'uri': uri,
              'recoveryCodes': List<String>.from(recovery),
            };

            _notice = uiText(
              context,
              'Add the setup key to your authenticator app. Save the recovery codes before confirming.',
              'அமைப்புக் குறியீட்டை அங்கீகார செயலியில் சேர்க்கவும். உறுதிப்படுத்துவதற்கு முன்பு மீட்புக் குறியீடுகளைச் சேமிக்கவும்.',
            );
          } else {
            await repository.verifyMfa(_otp.text.trim());

            if (!mounted || generation != authSession.generation) {
              return;
            }

            _otp.clear();
            _mfaProvision = null;
            _mfaCompleted = true;

            _notice = uiText(
              context,
              'MFA verified and enabled. Keep your saved recovery codes private.',
              'MFA உறுதிப்படுத்தப்பட்டு செயல்படுத்தப்பட்டது. மீட்புக் குறியீடுகளைப் பாதுகாப்பாக வைத்திருக்கவும்.',
            );
          }

          break;
      }
    } catch (error) {
      if (mounted &&
          (!_protectedAction || generation == authSession.generation)) {
        _error = authErrorMessage(error);
      }
    } finally {
      if (mounted &&
          (!_protectedAction || generation == authSession.generation)) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;

    final requiresLink =
        action == AccountAction.resetPassword && widget.token.isEmpty;

    final isMfa = action == AccountAction.setupMfa;

    final requiresSignIn =
        (isMfa ||
            (action == AccountAction.verifyEmail && widget.token.isEmpty)) &&
        !authSession.authenticated;

    final isPublicVerificationHelp =
        action == AccountAction.verifyEmail &&
        widget.token.isEmpty &&
        !authSession.authenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          uiText(
            context,
            'REQVIORA Account Security',
            'REQVIORA கணக்குப் பாதுகாப்பு',
          ),
        ),
        actions: const [LanguageSwitcher()],
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
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Text(
                        _title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),

                      const SizedBox(height: 12),

                      Text(_description),

                      const SizedBox(height: 20),

                      if (requiresLink)
                        Text(
                          uiText(
                            context,
                            'Open the secure link from your email to reset your password.',
                            'கடவுச்சொல்லை மீட்டமைக்க மின்னஞ்சலில் கிடைத்த பாதுகாப்பான இணைப்பைத் திறக்கவும்.',
                          ),
                        ),

                      if (isPublicVerificationHelp) ...[
                        Text(
                          uiText(
                            context,
                            'After registration, a verification link is requested for your email address.',
                            'பதிவு செய்த பிறகு உங்கள் மின்னஞ்சலுக்கு உறுதிப்படுத்தல் இணைப்பு கோரப்படும்.',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          uiText(
                            context,
                            'Check your inbox and spam folder, then open the verification link.',
                            'உங்கள் மின்னஞ்சல் மற்றும் தேவையற்ற அஞ்சல் கோப்புறையைச் சரிபார்த்து உறுதிப்படுத்தல் இணைப்பைத் திறக்கவும்.',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          uiText(
                            context,
                            'If your registration request failed to send the email, use Retry Email Verification on the registration screen while it is still available.',
                            'பதிவின்போது மின்னஞ்சல் அனுப்ப முடியவில்லை என்றால் பதிவு திரையில் உள்ள மீண்டும் முயற்சிக்கும் வசதியைப் பயன்படுத்தவும்.',
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          uiText(
                            context,
                            'If your account already exists and the retry is unavailable, contact support. Do not create a duplicate account.',
                            'ஏற்கனவே கணக்கு இருந்து மீண்டும் முயற்சிக்கும் வசதி கிடைக்கவில்லை என்றால் உதவி மையத்தை அணுகவும். மற்றொரு கணக்கை உருவாக்க வேண்டாம்.',
                          ),
                        ),
                      ],

                      if (requiresSignIn && !isPublicVerificationHelp)
                        Text(
                          uiText(
                            context,
                            'Sign in before using this protected operation.',
                            'இந்தப் பாதுகாக்கப்பட்ட செயலைப் பயன்படுத்த முதலில் உள்நுழையவும்.',
                          ),
                        ),

                      if (action == AccountAction.forgotPassword)
                        TextFormField(
                          key: const ValueKey('security-email'),

                          controller: _email,
                          enabled: !_busy,

                          keyboardType: TextInputType.emailAddress,

                          decoration: InputDecoration(
                            labelText: uiText(
                              context,
                              'Account email',
                              'கணக்கின் மின்னஞ்சல்',
                            ),
                          ),

                          validator:
                              (value) =>
                                  value != null &&
                                          value.contains('@') &&
                                          value.contains('.')
                                      ? null
                                      : uiText(
                                        context,
                                        'Enter a valid email address',
                                        'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்',
                                      ),
                        ),

                      if (action == AccountAction.resetPassword &&
                          !requiresLink) ...[
                        TextFormField(
                          key: const ValueKey('security-password'),

                          controller: _password,
                          obscureText: true,
                          enabled: !_busy,

                          decoration: InputDecoration(
                            labelText: uiText(
                              context,
                              'New password',
                              'புதிய கடவுச்சொல்',
                            ),
                          ),

                          validator:
                              (value) =>
                                  (value?.length ?? 0) >= 12
                                      ? null
                                      : uiText(
                                        context,
                                        'Use at least 12 characters',
                                        'குறைந்தது 12 எழுத்துகளைப் பயன்படுத்தவும்',
                                      ),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          key: const ValueKey('security-confirm-password'),

                          controller: _confirm,
                          obscureText: true,
                          enabled: !_busy,

                          decoration: InputDecoration(
                            labelText: uiText(
                              context,
                              'Confirm new password',
                              'புதிய கடவுச்சொல்லை உறுதிப்படுத்தவும்',
                            ),
                          ),

                          validator:
                              (value) =>
                                  value == _password.text
                                      ? null
                                      : uiText(
                                        context,
                                        'Passwords do not match',
                                        'கடவுச்சொற்கள் பொருந்தவில்லை',
                                      ),
                        ),
                      ],

                      if (isMfa && _mfaProvision != null) ...[
                        const SizedBox(height: 12),

                        Text(
                          uiText(
                            context,
                            'Authenticator setup key (private):',
                            'அங்கீகார அமைப்புக் குறியீடு (ரகசியமானது):',
                          ),
                        ),

                        SelectableText(
                          (_mfaProvision!['secret'] ?? '').toString(),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          uiText(
                            context,
                            'Authenticator setup URI (private):',
                            'அங்கீகார அமைப்பு URI (ரகசியமானது):',
                          ),
                        ),

                        SelectableText(
                          (_mfaProvision!['uri'] ?? '').toString(),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          uiText(
                            context,
                            'Recovery codes — store offline and never share:',
                            'மீட்புக் குறியீடுகள் — பாதுகாப்பாகச் சேமிக்கவும். யாருடனும் பகிர வேண்டாம்:',
                          ),
                        ),

                        for (final code
                            in (_mfaProvision!['recoveryCodes'] as List? ?? []))
                          SelectableText(code.toString()),

                        const SizedBox(height: 12),

                        TextFormField(
                          key: const ValueKey('security-otp'),

                          controller: _otp,
                          enabled: !_busy,

                          keyboardType: TextInputType.number,

                          decoration: InputDecoration(
                            labelText: uiText(
                              context,
                              '6-digit authenticator code',
                              '6 இலக்க அங்கீகாரக் குறியீடு',
                            ),
                          ),

                          validator:
                              (value) =>
                                  RegExp(
                                        r'^\d{6}$',
                                      ).hasMatch(value?.trim() ?? '')
                                      ? null
                                      : uiText(
                                        context,
                                        'Enter a 6-digit code',
                                        '6 இலக்கக் குறியீட்டை உள்ளிடவும்',
                                      ),
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

                      if (!isPublicVerificationHelp)
                        FilledButton(
                          onPressed:
                              (_busy ||
                                      _mfaCompleted ||
                                      requiresLink ||
                                      requiresSignIn)
                                  ? null
                                  : _submit,

                          child: Text(
                            _busy
                                ? uiText(
                                  context,
                                  'Processing…',
                                  'செயலாக்கப்படுகிறது…',
                                )
                                : switch (action) {
                                  AccountAction.forgotPassword => uiText(
                                    context,
                                    'Send reset link',
                                    'மீட்டமைப்பு இணைப்பை அனுப்பு',
                                  ),

                                  AccountAction.resetPassword => uiText(
                                    context,
                                    'Reset password',
                                    'கடவுச்சொல்லை மீட்டமைக்கவும்',
                                  ),

                                  AccountAction.verifyEmail =>
                                    widget.token.isEmpty
                                        ? uiText(
                                          context,
                                          'Request verification email',
                                          'உறுதிப்படுத்தல் மின்னஞ்சலைக் கோருக',
                                        )
                                        : uiText(
                                          context,
                                          'Confirm email',
                                          'மின்னஞ்சலை உறுதிப்படுத்துக',
                                        ),

                                  AccountAction.setupMfa =>
                                    _mfaCompleted
                                        ? uiText(
                                          context,
                                          'MFA enabled',
                                          'MFA செயல்படுத்தப்பட்டது',
                                        )
                                        : _mfaProvision == null
                                        ? uiText(
                                          context,
                                          'Start MFA setup',
                                          'MFA அமைப்பைத் தொடங்குக',
                                        )
                                        : uiText(
                                          context,
                                          'Verify authenticator',
                                          'அங்கீகாரக் குறியீட்டைச் சரிபார்க்கவும்',
                                        ),
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

                        child: Text(
                          uiText(
                            context,
                            'Return to REQVIORA',
                            'REQVIORA-க்குத் திரும்புக',
                          ),
                        ),
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
