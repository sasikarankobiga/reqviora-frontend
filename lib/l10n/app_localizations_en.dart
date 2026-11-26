// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'REQVIORA';

  @override
  String get accountSecurity => 'REQVIORA Account Security';

  @override
  String get forgotPassword => 'Forgot password';

  @override
  String get forgotPasswordDescription =>
      'Request a secure password-reset link.';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get verifyEmail => 'Verify your email';

  @override
  String get mfaSetup => 'Authenticator setup';

  @override
  String get accountEmail => 'Account email';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get returnToReqviora => 'Return to REQVIORA';

  @override
  String get adminTitle => 'REQVIORA Administration';

  @override
  String get workspace => 'Workspace';

  @override
  String get adminRequiresAuthentication =>
      'Administration requires real authentication.';

  @override
  String get verifyAdminAccess => 'Verify administrator access';

  @override
  String get adminMetadataDescription =>
      'Read-only platform metadata. Each request requires a fresh MFA code.';

  @override
  String get authenticatorCode => 'Authenticator code';

  @override
  String get loadRefresh => 'Load / refresh';

  @override
  String get verifyAccess => 'Verify access';
}
