// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'REQVIORA';

  @override
  String get accountSecurity => 'REQVIORA கணக்கு பாதுகாப்பு';

  @override
  String get forgotPassword => 'கடவுச்சொல்லை மறந்துவிட்டீர்களா';

  @override
  String get forgotPasswordDescription =>
      'பாதுகாப்பான கடவுச்சொல் மீட்டமைப்பு இணைப்பைக் கோருங்கள்.';

  @override
  String get resetPassword => 'கடவுச்சொல்லை மீட்டமை';

  @override
  String get verifyEmail => 'மின்னஞ்சலை உறுதிப்படுத்துங்கள்';

  @override
  String get mfaSetup => 'அங்கீகார செயலி அமைப்பு';

  @override
  String get accountEmail => 'கணக்கு மின்னஞ்சல்';

  @override
  String get sendResetLink => 'மீட்டமைப்பு இணைப்பை அனுப்பு';

  @override
  String get returnToReqviora => 'REQVIORA-க்கு திரும்பு';

  @override
  String get adminTitle => 'REQVIORA நிர்வாகம்';

  @override
  String get workspace => 'பணிப்பகுதி';

  @override
  String get adminRequiresAuthentication =>
      'நிர்வாகத்திற்கு உண்மையான உள்நுழைவு தேவை.';

  @override
  String get verifyAdminAccess => 'நிர்வாக அணுகலை உறுதிப்படுத்துங்கள்';

  @override
  String get adminMetadataDescription =>
      'வாசிப்பு மட்டும் தளத் தகவல். ஒவ்வொரு கோரிக்கைக்கும் புதிய MFA குறியீடு தேவை.';

  @override
  String get authenticatorCode => 'அங்கீகார குறியீடு';

  @override
  String get loadRefresh => 'ஏற்று / புதுப்பி';

  @override
  String get verifyAccess => 'அணுகலை உறுதிப்படுத்து';
}
