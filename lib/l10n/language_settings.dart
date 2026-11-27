import 'package:flutter/material.dart';

/// Application language only. Never changes backend contract values.
final appLocale = ValueNotifier<Locale>(const Locale('en'));
bool _appLocaleExplicitlySelected = false;

void selectAppLocale(Locale locale) {
  _appLocaleExplicitlySelected = true;
  appLocale.value = locale;
}

void resetAppLocalePreference() {
  _appLocaleExplicitlySelected = false;
  appLocale.value = const Locale('en');
}

Locale effectiveAppLocale(Locale selected, Iterable<Locale> systemLocales) {
  if (_appLocaleExplicitlySelected) return selected;
  return systemLocales.firstWhere(
    (locale) => supportedAppLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    ),
    orElse: () => selected,
  );
}

const supportedAppLocales = <Locale>[Locale('en'), Locale('ta')];

String uiText(BuildContext context, String english, String tamil) {
  final locale = Localizations.maybeLocaleOf(context);
  return locale?.languageCode == 'ta' ? tamil : english;
}

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final current = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    return PopupMenuButton<String>(
      key: const ValueKey('app-language-switcher'),
      tooltip: uiText(context, 'Change language', 'மொழியை மாற்றவும்'),
      initialValue: current,
      onSelected: (value) {
        if (value == 'en' || value == 'ta') {
          selectAppLocale(Locale(value));
        }
      },
      itemBuilder:
          (_) => const [
            PopupMenuItem(value: 'en', child: Text('English')),
            PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
          ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 18),
            const SizedBox(width: 6),
            Text(current == 'ta' ? 'தமிழ்' : 'EN'),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// Translates known interface labels only.
/// Never use translated values as API identifiers.
String localizedLabel(BuildContext context, String value) {
  const tamilLabels = <String, String>{
    'Workspace / Create Project': 'பணியிடம் / புதிய திட்டம்',
    'Project setup': 'திட்ட அமைப்பு',
    'Create a new project': 'புதிய திட்டத்தை உருவாக்குங்கள்',
    'Start with the basics. You can refine these details inside Builder Step 01.':
        'அடிப்படைத் தகவல்களுடன் தொடங்குங்கள். முதல் படியில் அவற்றை மேம்படுத்தலாம்.',
    'Project details': 'திட்ட விவரங்கள்',
    'A simple, single-screen setup.': 'எளிய ஒரே திரை அமைப்பு.',
    'Project name *': 'திட்டப் பெயர் *',
    'Project name (required)': 'திட்டப் பெயர் (அவசியம்)',
    'e.g. Coffee Shop App': 'உதாரணம்: காபி கடை செயலி',
    'Enter a project name': 'திட்டப் பெயரை உள்ளிடுங்கள்',
    'Description': 'விளக்கம்',
    'What problem will your software solve?':
        'உங்கள் மென்பொருள் எந்தப் பிரச்சினையைத் தீர்க்கும்?',
    'Category / industry': 'வகை / தொழில்துறை',
    'Workspace': 'பணியிடம்',
    'Design target *': 'வடிவமைப்பு இலக்கு *',
    'Cancel': 'ரத்து செய்',
    'Create project': 'திட்டத்தை உருவாக்கு',
    'Creating…': 'உருவாக்கப்படுகிறது…',
    'Software / SaaS': 'மென்பொருள் / SaaS',
    'Food & Beverage': 'உணவு மற்றும் பானங்கள்',
    'E-commerce': 'மின்னணு வணிகம்',
    'Education': 'கல்வி',
    'Healthcare': 'சுகாதாரம்',
    'Finance': 'நிதி',
    'Other': 'பிற',
    'Web': 'இணையம்',
    'Mobile': 'கையடக்கச் சாதனம்',
    'Desktop': 'கணினி',
    'Your idea, structured.': 'உங்கள் யோசனை, ஒழுங்கமைக்கப்பட்ட வடிவில்.',
    'Project / Overview': 'திட்டம் / மேலோட்டம்',
    'Project workspace': 'திட்டப் பணியிடம்',
    'Input Studio': 'உள்ளீட்டு மையம்',
    'Requirements Review': 'தேவைகள் மதிப்பாய்வு',
    '8-Step Builder': '8 படி வடிவமைப்பு',
    'Builder journey': 'வடிவமைப்புப் பயணம்',
    'Continue': 'தொடரவும்',
    'Your workflow': 'உங்கள் பணிப்பாய்வு',
    'Project identity': 'திட்ட அடையாளம்',
    'Purpose & audience': 'நோக்கம் மற்றும் பயனர்கள்',
    'Scope & success': 'திட்ட வரம்பும் வெற்றியும்',
    'Project Name *': 'திட்டப் பெயர் *',
    'Project Description': 'திட்ட விளக்கம்',
    'Project Category / Industry': 'திட்ட வகை / தொழில்துறை',
    'Project Tagline': 'திட்டக் குறிக்கோள் வாசகம்',
    'Problem Statement': 'பிரச்சினை விளக்கம்',
    'Project Goals & Objectives': 'திட்ட இலக்குகளும் நோக்கங்களும்',
    'Target Audience': 'இலக்குப் பயனர்கள்',
    'User Personas': 'பயனர் சுயவிவரங்கள்',
    'User Roles & Responsibilities': 'பயனர் பாத்திரங்களும் பொறுப்புகளும்',
    'In Scope': 'திட்ட வரம்பிற்குள்',
    'Out of Scope': 'திட்ட வரம்பிற்கு வெளியே',
    'Business Constraints & Assumptions':
        'வணிகக் கட்டுப்பாடுகளும் அனுமானங்களும்',
    'Project Success Criteria': 'திட்ட வெற்றிக்கான அளவுகோல்கள்',
    'Back to overview': 'மேலோட்டத்திற்குத் திரும்புக',
    'Save Draft': 'வரைவைச் சேமி',
    'Save & Continue': 'சேமித்துத் தொடரவும்',
    'Saving…': 'சேமிக்கப்படுகிறது…',
    'Project / Input Studio': 'திட்டம் / உள்ளீட்டு மையம்',
    'Turn ideas into clear requirements':
        'யோசனைகளைத் தெளிவான தேவைகளாக மாற்றுங்கள்',
    'Text input': 'உரை உள்ளீடு',
    'Manual': 'கைமுறை உள்ளீடு',
    'Documents': 'ஆவணங்கள்',
    'Voice': 'குரல்',
    'Available': 'கிடைக்கிறது',
    'Not connected': 'இணைக்கப்படவில்லை',
    'Add a text source': 'உரை மூலத்தைச் சேர்க்கவும்',
    'Source title': 'மூலத் தலைப்பு',
    'Requirement source content': 'தேவைகளின் மூல உள்ளடக்கம்',
    'Upload PDF / DOCX / TXT': 'PDF / DOCX / TXT பதிவேற்றுக',
    'Save source': 'மூலத்தைச் சேமி',
    'Suggest using local rules': 'உள்ளூர் விதிகளின் மூலம் பரிந்துரை',
    'Review suggestions': 'பரிந்துரைகளை மதிப்பாய்வு செய்',
    'No saved sources yet.': 'சேமித்த மூலங்கள் இன்னும் இல்லை.',
    'You are in control': 'கட்டுப்பாடு உங்களிடம் உள்ளது',
    'Accept': 'ஏற்றுக்கொள்',
    'Edit & Accept': 'திருத்தி ஏற்றுக்கொள்',
    'Reject': 'நிராகரி',
    'Defer': 'ஒத்திவை',
    'Confirm': 'உறுதிப்படுத்து',
    'Requirement name': 'தேவையின் பெயர்',
    'Edit & confirm suggestion': 'பரிந்துரையைத் திருத்தி உறுதிப்படுத்து',
    'Open Input Studio': 'உள்ளீட்டு மையத்தைத் திறக்கவும்',
    'Continue to Builder': 'வடிவமைப்பிற்குத் தொடரவும்',
    'Email is required': 'மின்னஞ்சல் அவசியம்',
    'Enter a valid email address': 'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்',
    'Password is required': 'கடவுச்சொல் அவசியம்',
    'Password must contain at least 12 characters':
        'கடவுச்சொல்லில் குறைந்தது 12 எழுத்துகள் இருக்க வேண்டும்',
    'Confirm your password': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
    'Passwords do not match': 'கடவுச்சொற்கள் பொருந்தவில்லை',
  };

  return Localizations.maybeLocaleOf(context)?.languageCode == 'ta'
      ? tamilLabels[value] ?? advancedTamilLabels[value] ?? value
      : value;
}

String? localizedValidation(BuildContext context, String? error) {
  return error == null ? null : localizedLabel(context, error);
}

String localizedStageName(BuildContext context, int index, String english) {
  const tamil = [
    'அடையாளமும் பயனர்களும்',
    'அம்சங்களும் திரைகளும்',
    'வழிசெலுத்தல்',
    'தோற்றமும் பிராண்ட் வடிவமைப்பும்',
    'கூறுகளும் திரை அமைப்பும்',
    'ஊடாடலும் நிலைகளும்',
    'AI வடிவமைப்புப் பணியிடம்',
    'மதிப்பாய்வும் ஏற்றுமதியும்',
  ];

  return Localizations.maybeLocaleOf(context)?.languageCode == 'ta' &&
          index >= 0 &&
          index < tamil.length
      ? tamil[index]
      : english;
}

/// Translates static interface text without modifying API identifiers.
class LocalizedUiText extends StatelessWidget {
  const LocalizedUiText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      Localizations.maybeLocaleOf(context)?.languageCode == 'ta'
          ? localizedLabel(context, message)
          : message,
    );
  }
}

const advancedTamilLabels = <String, String>{
  'Administration': '\u0BA8\u0BBF\u0BB0\u0BCD\u0BB5\u0BBE\u0B95\u0BAE\u0BCD',
  'Overview': '\u0BAE\u0BC7\u0BB2\u0BCB\u0B9F\u0BCD\u0B9F\u0BAE\u0BCD',
  'Users': '\u0BAA\u0BAF\u0BA9\u0BB0\u0BCD\u0B95\u0BB3\u0BCD',
  'Roles':
      '\u0BAA\u0BBE\u0BA4\u0BCD\u0BA4\u0BBF\u0BB0\u0B99\u0BCD\u0B95\u0BB3\u0BCD',
  'Projects': '\u0BA4\u0BBF\u0B9F\u0BCD\u0B9F\u0B99\u0BCD\u0B95\u0BB3\u0BCD',
  'Audit': '\u0BA4\u0BA3\u0BBF\u0B95\u0BCD\u0B95\u0BC8',
  'Login security':
      '\u0B89\u0BB3\u0BCD\u0BA8\u0BC1\u0BB4\u0BC8\u0BB5\u0BC1 \u0BAA\u0BBE\u0BA4\u0BC1\u0B95\u0BBE\u0BAA\u0BCD\u0BAA\u0BC1',
  'System report':
      '\u0B85\u0BAE\u0BC8\u0BAA\u0BCD\u0BAA\u0BC1 \u0B85\u0BB1\u0BBF\u0B95\u0BCD\u0B95\u0BC8',
  'System health':
      '\u0B85\u0BAE\u0BC8\u0BAA\u0BCD\u0BAA\u0BBF\u0BA9\u0BCD \u0BA8\u0BBF\u0BB2\u0BC8',
  'Operations dashboard':
      '\u0B9A\u0BC6\u0BAF\u0BB2\u0BCD\u0BAA\u0BBE\u0B9F\u0BCD\u0B9F\u0BC1 \u0BAE\u0BC1\u0B95\u0BAA\u0BCD\u0BAA\u0BC1\u0BAA\u0BCD \u0BAA\u0BB2\u0B95\u0BC8',
  'My account': '\u0B8E\u0BA9\u0BA4\u0BC1 \u0B95\u0BA3\u0B95\u0BCD\u0B95\u0BC1',
  'Search': '\u0BA4\u0BC7\u0B9F\u0BB2\u0BCD',
  'Authenticator code':
      '\u0B85\u0B99\u0BCD\u0B95\u0BC0\u0B95\u0BBE\u0BB0\u0B95\u0BCD \u0B95\u0BC1\u0BB1\u0BBF\u0BAF\u0BC0\u0B9F\u0BC1',
  'Enter a current six-digit code.':
      '\u0BA4\u0BB1\u0BCD\u0BAA\u0BCB\u0BA4\u0BC8\u0BAF \u0B86\u0BB1\u0BC1 \u0B87\u0BB2\u0B95\u0BCD\u0B95\u0B95\u0BCD \u0B95\u0BC1\u0BB1\u0BBF\u0BAF\u0BC0\u0B9F\u0BCD\u0B9F\u0BC8 \u0B89\u0BB3\u0BCD\u0BB3\u0BBF\u0B9F\u0BB5\u0BC1\u0BAE\u0BCD.',
  'Verify and load':
      '\u0B9A\u0BB0\u0BBF\u0BAA\u0BBE\u0BB0\u0BCD\u0BA4\u0BCD\u0BA4\u0BC1 \u0B8F\u0BB1\u0BCD\u0BB1\u0BB5\u0BC1\u0BAE\u0BCD',
  'Loading...':
      '\u0B8F\u0BB1\u0BCD\u0BB1\u0BAA\u0BCD\u0BAA\u0B9F\u0BC1\u0B95\u0BBF\u0BB1\u0BA4\u0BC1...',
  'No records found.':
      '\u0BAA\u0BA4\u0BBF\u0BB5\u0BC1\u0B95\u0BB3\u0BCD \u0B8E\u0BA4\u0BC1\u0BB5\u0BC1\u0BAE\u0BCD \u0B87\u0BB2\u0BCD\u0BB2\u0BC8.',
  'Not available':
      '\u0B95\u0BBF\u0B9F\u0BC8\u0B95\u0BCD\u0B95\u0BB5\u0BBF\u0BB2\u0BCD\u0BB2\u0BC8',
  'Next': '\u0B85\u0B9F\u0BC1\u0BA4\u0BCD\u0BA4\u0BA4\u0BC1',
  'Page': '\u0BAA\u0B95\u0BCD\u0B95\u0BAE\u0BCD',
  'records': '\u0BAA\u0BA4\u0BBF\u0BB5\u0BC1\u0B95\u0BB3\u0BCD',
  'System status':
      '\u0B85\u0BAE\u0BC8\u0BAA\u0BCD\u0BAA\u0BBF\u0BA9\u0BCD \u0BA8\u0BBF\u0BB2\u0BC8',
  'Enter a valid six-digit authenticator code.':
      '\u0B9A\u0BB0\u0BBF\u0BAF\u0BBE\u0BA9 \u0B86\u0BB1\u0BC1 \u0B87\u0BB2\u0B95\u0BCD\u0B95 \u0B85\u0B99\u0BCD\u0B95\u0BC0\u0B95\u0BBE\u0BB0\u0B95\u0BCD \u0B95\u0BC1\u0BB1\u0BBF\u0BAF\u0BC0\u0B9F\u0BCD\u0B9F\u0BC8 \u0B89\u0BB3\u0BCD\u0BB3\u0BBF\u0B9F\u0BB5\u0BC1\u0BAE\u0BCD.',
  'Invalid request. Check the entered values.':
      '\u0BA4\u0BB5\u0BB1\u0BBE\u0BA9 \u0B95\u0BCB\u0BB0\u0BBF\u0B95\u0BCD\u0B95\u0BC8. \u0B89\u0BB3\u0BCD\u0BB3\u0BC0\u0B9F\u0BC1\u0B95\u0BB3\u0BC8\u0B9A\u0BCD \u0B9A\u0BB0\u0BBF\u0BAA\u0BBE\u0BB0\u0BCD\u0B95\u0BCD\u0B95\u0BB5\u0BC1\u0BAE\u0BCD.',
  'Authentication or MFA verification failed.':
      '\u0B85\u0B99\u0BCD\u0B95\u0BC0\u0B95\u0BBE\u0BB0\u0BAE\u0BCD \u0B85\u0BB2\u0BCD\u0BB2\u0BA4\u0BC1 MFA \u0B9A\u0BB0\u0BBF\u0BAA\u0BBE\u0BB0\u0BCD\u0BAA\u0BCD\u0BAA\u0BC1 \u0BA4\u0BCB\u0BB2\u0BCD\u0BB5\u0BBF\u0BAF\u0B9F\u0BC8\u0BA8\u0BCD\u0BA4\u0BA4\u0BC1.',
  'You are not authorized to access administration.':
      '\u0BA8\u0BBF\u0BB0\u0BCD\u0BB5\u0BBE\u0B95\u0BA4\u0BCD\u0BA4\u0BC8 \u0B85\u0BA3\u0BC1\u0B95 \u0B89\u0B99\u0BCD\u0B95\u0BB3\u0BC1\u0B95\u0BCD\u0B95\u0BC1 \u0B85\u0BA9\u0BC1\u0BAE\u0BA4\u0BBF \u0B87\u0BB2\u0BCD\u0BB2\u0BC8.',
  'Too many requests. Try again later.':
      '\u0B85\u0BA4\u0BBF\u0B95\u0BAE\u0BBE\u0BA9 \u0B95\u0BCB\u0BB0\u0BBF\u0B95\u0BCD\u0B95\u0BC8\u0B95\u0BB3\u0BCD. \u0BAA\u0BBF\u0BA9\u0BCD\u0BA9\u0BB0\u0BCD \u0BAE\u0BC1\u0BAF\u0BB1\u0BCD\u0B9A\u0BBF\u0B95\u0BCD\u0B95\u0BB5\u0BC1\u0BAE\u0BCD.',
  'Cannot connect to the backend.':
      '\u0BAA\u0BBF\u0BA9\u0BCD\u0BA4\u0BB3\u0BA4\u0BCD\u0BA4\u0BC1\u0B9F\u0BA9\u0BCD \u0B87\u0BA3\u0BC8\u0B95\u0BCD\u0B95 \u0BAE\u0BC1\u0B9F\u0BBF\u0BAF\u0BB5\u0BBF\u0BB2\u0BCD\u0BB2\u0BC8.',
  'Unable to load administration data.':
      '\u0BA8\u0BBF\u0BB0\u0BCD\u0BB5\u0BBE\u0B95\u0BA4\u0BCD \u0BA4\u0BB0\u0BB5\u0BC8 \u0B8F\u0BB1\u0BCD\u0BB1 \u0BAE\u0BC1\u0B9F\u0BBF\u0BAF\u0BB5\u0BBF\u0BB2\u0BCD\u0BB2\u0BC8.',
  'The server returned an incompatible response.':
      '\u0BAA\u0BCA\u0BB0\u0BC1\u0BA8\u0BCD\u0BA4\u0BBE\u0BA4 \u0BAA\u0BA4\u0BBF\u0BB2\u0BCD \u0B95\u0BBF\u0B9F\u0BC8\u0BA4\u0BCD\u0BA4\u0BC1\u0BB3\u0BCD\u0BB3\u0BA4\u0BC1.',
  'Unable to complete the request. Please retry.':
      '\u0B95\u0BCB\u0BB0\u0BBF\u0B95\u0BCD\u0B95\u0BC8\u0BAF\u0BC8 \u0BAE\u0BC1\u0B9F\u0BBF\u0B95\u0BCD\u0B95 \u0BAE\u0BC1\u0B9F\u0BBF\u0BAF\u0BB5\u0BBF\u0BB2\u0BCD\u0BB2\u0BC8. \u0BAE\u0BC0\u0BA3\u0BCD\u0B9F\u0BC1\u0BAE\u0BCD \u0BAE\u0BC1\u0BAF\u0BB1\u0BCD\u0B9A\u0BBF\u0B95\u0BCD\u0B95\u0BB5\u0BC1\u0BAE\u0BCD.',
  'Read-only administration. Access is verified by the server for every request.':
      '\u0BAA\u0B9F\u0BBF\u0B95\u0BCD\u0B95 \u0BAE\u0B9F\u0BCD\u0B9F\u0BC1\u0BAE\u0BCD \u0B85\u0BA9\u0BC1\u0BAE\u0BA4\u0BBF\u0B95\u0BCD\u0B95\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F \u0BA8\u0BBF\u0BB0\u0BCD\u0BB5\u0BBE\u0B95\u0BAE\u0BCD. \u0B92\u0BB5\u0BCD\u0BB5\u0BCA\u0BB0\u0BC1 \u0B95\u0BCB\u0BB0\u0BBF\u0B95\u0BCD\u0B95\u0BC8\u0BAF\u0BC1\u0BAE\u0BCD \u0BAA\u0BBF\u0BA9\u0BCD\u0BA4\u0BB3\u0BA4\u0BCD\u0BA4\u0BBF\u0BB2\u0BCD \u0B9A\u0BB0\u0BBF\u0BAA\u0BBE\u0BB0\u0BCD\u0B95\u0BCD\u0B95\u0BAA\u0BCD\u0BAA\u0B9F\u0BC1\u0BAE\u0BCD.',
  'Id': '\u0B85\u0B9F\u0BC8\u0BAF\u0BBE\u0BB3 \u0B8E\u0BA3\u0BCD',
  'Display Name':
      '\u0B95\u0BBE\u0B9F\u0BCD\u0B9A\u0BBF\u0BAA\u0BCD \u0BAA\u0BC6\u0BAF\u0BB0\u0BCD',
  'Email': '\u0BAE\u0BBF\u0BA9\u0BCD\u0BA9\u0B9E\u0BCD\u0B9A\u0BB2\u0BCD',
  'Email Verified':
      '\u0BAE\u0BBF\u0BA9\u0BCD\u0BA9\u0B9E\u0BCD\u0B9A\u0BB2\u0BCD \u0B9A\u0BB0\u0BBF\u0BAA\u0BBE\u0BB0\u0BCD\u0BAA\u0BCD\u0BAA\u0BC1',
  'Mfa Enabled':
      'MFA \u0B9A\u0BC6\u0BAF\u0BB2\u0BCD\u0BAA\u0B9F\u0BC1\u0BA4\u0BCD\u0BA4\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F\u0BA4\u0BC1',
  'Role Id':
      '\u0BAA\u0BBE\u0BA4\u0BCD\u0BA4\u0BBF\u0BB0 \u0B85\u0B9F\u0BC8\u0BAF\u0BBE\u0BB3\u0BAE\u0BCD',
  'Name': '\u0BAA\u0BC6\u0BAF\u0BB0\u0BCD',
  'Industry': '\u0BA4\u0BCA\u0BB4\u0BBF\u0BB2\u0BCD\u0BA4\u0BC1\u0BB1\u0BC8',
  'Primary Platform':
      '\u0BAE\u0BC1\u0BA4\u0BA9\u0BCD\u0BAE\u0BC8 \u0BA4\u0BB3\u0BAE\u0BCD',
  'Owner Id':
      '\u0B89\u0BB0\u0BBF\u0BAE\u0BC8\u0BAF\u0BBE\u0BB3\u0BB0\u0BCD \u0B85\u0B9F\u0BC8\u0BAF\u0BBE\u0BB3\u0BAE\u0BCD',
  'Workspace Id':
      '\u0BAA\u0BA3\u0BBF\u0BAF\u0BBF\u0B9F \u0B85\u0B9F\u0BC8\u0BAF\u0BBE\u0BB3\u0BAE\u0BCD',
  'Created At':
      '\u0B89\u0BB0\u0BC1\u0BB5\u0BBE\u0B95\u0BCD\u0B95\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F \u0BA8\u0BC7\u0BB0\u0BAE\u0BCD',
  'User Id':
      '\u0BAA\u0BAF\u0BA9\u0BB0\u0BCD \u0B85\u0B9F\u0BC8\u0BAF\u0BBE\u0BB3\u0BAE\u0BCD',
  'Method': '\u0BAE\u0BC1\u0BB1\u0BC8',
  'Path': '\u0BAA\u0BBE\u0BA4\u0BC8',
  'Status Code':
      '\u0BA8\u0BBF\u0BB2\u0BC8\u0B95\u0BCD \u0B95\u0BC1\u0BB1\u0BBF\u0BAF\u0BC0\u0B9F\u0BC1',
  'Occurred At':
      '\u0BA8\u0BBF\u0B95\u0BB4\u0BCD\u0BA8\u0BCD\u0BA4 \u0BA8\u0BC7\u0BB0\u0BAE\u0BCD',
  'Total Attempts':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BAE\u0BC1\u0BAF\u0BB1\u0BCD\u0B9A\u0BBF\u0B95\u0BB3\u0BCD',
  'Failed Attempts':
      '\u0BA4\u0BCB\u0BB2\u0BCD\u0BB5\u0BBF\u0BAF\u0BC1\u0BB1\u0BCD\u0BB1 \u0BAE\u0BC1\u0BAF\u0BB1\u0BCD\u0B9A\u0BBF\u0B95\u0BB3\u0BCD',
  'Successful Attempts':
      '\u0BB5\u0BC6\u0BB1\u0BCD\u0BB1\u0BBF\u0B95\u0BB0\u0BAE\u0BBE\u0BA9 \u0BAE\u0BC1\u0BAF\u0BB1\u0BCD\u0B9A\u0BBF\u0B95\u0BB3\u0BCD',
  'Otp Required Attempts':
      'OTP \u0BA4\u0BC7\u0BB5\u0BC8\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F \u0BAE\u0BC1\u0BAF\u0BB1\u0BCD\u0B9A\u0BBF\u0B95\u0BB3\u0BCD',
  'Total Users':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BAA\u0BAF\u0BA9\u0BB0\u0BCD\u0B95\u0BB3\u0BCD',
  'Total Projects':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BA4\u0BBF\u0B9F\u0BCD\u0B9F\u0B99\u0BCD\u0B95\u0BB3\u0BCD',
  'Total Drafts':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BB5\u0BB0\u0BC8\u0BB5\u0BC1\u0B95\u0BB3\u0BCD',
  'Total Roles':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BAA\u0BBE\u0BA4\u0BCD\u0BA4\u0BBF\u0BB0\u0B99\u0BCD\u0B95\u0BB3\u0BCD',
  'Total Audit Events':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BA4\u0BA3\u0BBF\u0B95\u0BCD\u0B95\u0BC8 \u0BA8\u0BBF\u0B95\u0BB4\u0BCD\u0BB5\u0BC1\u0B95\u0BB3\u0BCD',
  'Total Failed Logins':
      '\u0BAE\u0BCA\u0BA4\u0BCD\u0BA4 \u0BA4\u0BCB\u0BB2\u0BCD\u0BB5\u0BBF\u0BAF\u0BC1\u0BB1\u0BCD\u0BB1 \u0B89\u0BB3\u0BCD\u0BA8\u0BC1\u0BB4\u0BC8\u0BB5\u0BC1\u0B95\u0BB3\u0BCD',
  'Generated At Utc':
      '\u0B89\u0BB0\u0BC1\u0BB5\u0BBE\u0B95\u0BCD\u0B95\u0BAA\u0BCD\u0BAA\u0B9F\u0BCD\u0B9F UTC \u0BA8\u0BC7\u0BB0\u0BAE\u0BCD',
  'Drafts': '\u0BB5\u0BB0\u0BC8\u0BB5\u0BC1\u0B95\u0BB3\u0BCD',
  'Audit Events':
      '\u0BA4\u0BA3\u0BBF\u0B95\u0BCD\u0B95\u0BC8 \u0BA8\u0BBF\u0B95\u0BB4\u0BCD\u0BB5\u0BC1\u0B95\u0BB3\u0BCD',
  'Status': '\u0BA8\u0BBF\u0BB2\u0BC8',
  'Read-only workspace': 'படிக்க மட்டும் அனுமதிக்கப்பட்ட பணியிடம்',
  'Project overview': 'திட்ட மேலோட்டம்',
  'Next step': 'அடுத்த படி',
  'Saved visual draft': 'சேமிக்கப்பட்ட காட்சி வரைவு',
  'Canonical Blueprint': 'அதிகாரப்பூர்வ வடிவமைப்பு வரைவு',
  'Feature catalogue': 'அம்சங்களின் பட்டியல்',
  'Screens & feature mapping': 'திரைகள் மற்றும் அம்ச இணைப்புகள்',
  'Navigation connections': 'வழிசெலுத்தல் இணைப்புகள்',
  'Interaction & state rules': 'ஊடாடல் மற்றும் நிலை விதிகள்',
  'Components Studio': 'கூறுகள் வடிவமைப்பு மையம்',
  'Previous': 'முந்தையது',
  'Add a screen first': 'முதலில் ஒரு திரையைச் சேர்க்கவும்',
  'Reuse component on screen': 'திரையில் கூறை மீண்டும் பயன்படுத்தவும்',
  'Cancel': 'ரத்து செய்',
  'Reuse': 'மீண்டும் பயன்படுத்து',
  'Edit': 'திருத்து',
  'Remove': 'நீக்கு',
  'Remove this item?': 'இந்த உருப்படியை நீக்கவா?',
  'Add': 'சேர்',
  'Navigation diagnostics': 'வழிசெலுத்தல் சரிபார்ப்பு',
  'No items yet. Add your first item to get started.':
      'உருப்படிகள் இல்லை. முதலில் ஒன்றைச் சேர்க்கவும்.',
  'Map features to this screen': 'அம்சங்களை இந்தத் திரையுடன் இணைக்கவும்',
  'Add features first': 'முதலில் அம்சங்களைச் சேர்க்கவும்',
  'Required': 'அவசியம்',
  'Require a value for this input': 'இந்த உள்ளீட்டிற்கு மதிப்பு அவசியம்',
  'Dense layout': 'நெருக்கமான திரை அமைப்பு',
  'Striped rows': 'மாறுபட்ட நிற வரிசைகள்',
  'Enabled': 'செயல்படுத்தப்பட்டது',
  'Allow button interaction': 'பொத்தான் செயல்பாட்டை அனுமதி',
  'Conditional Visibility': 'நிபந்தனை அடிப்படையிலான காட்சி',
  'Save': 'சேமி',
  'Brand & theme': 'பிராண்ட் மற்றும் தோற்றம்',
  'Save Theme': 'தோற்றத்தைச் சேமி',
  'Discard unsaved visual changes?': 'சேமிக்காத காட்சி மாற்றங்களை நீக்கவா?',
  'Your last saved visual draft will remain unchanged.':
      'கடைசியாகச் சேமித்த காட்சி வரைவு மாறாது.',
  'Discard changes': 'மாற்றங்களை நீக்கு',
  'Discard Changes': 'மாற்றங்களை நீக்கு',
  'Safe AI Regeneration': 'பாதுகாப்பான AI மீள் உருவாக்கம்',
  'I consent to AI processing of this Blueprint.':
      'இந்த வடிவமைப்பு வரைவை AI செயலாக்க அனுமதிக்கிறேன்.',
  'Regenerate': 'மீண்டும் உருவாக்கு',
  'Generate Blueprint': 'வடிவமைப்பு வரைவை உருவாக்கு',
  'Generate & save': 'உருவாக்கிச் சேமி',
  'Blueprint & UI Studio': 'வடிவமைப்பு மற்றும் UI மையம்',
  'Autosave (2s)': 'தானியங்கிச் சேமிப்பு (2 வினாடிகள்)',
  'Generate Local Preview': 'உள்ளூர் முன்னோட்டத்தை உருவாக்கு',
  'Generate & Save Blueprint': 'வடிவமைப்பு வரைவை உருவாக்கிச் சேமி',
  'Save Visual Draft': 'காட்சி வரைவைச் சேமி',
  'Local simulation - not validated':
      'உள்ளூர் உருவகப்படுத்தல் - சரிபார்க்கப்படவில்லை',
  'Visual Design Workspace': 'காட்சி வடிவமைப்புப் பணியிடம்',
  'Undo': 'முந்தைய நிலைக்கு மாற்று',
  'Redo': 'மீண்டும் செய்',
  'Approve validated design?': 'சரிபார்க்கப்பட்ட வடிவமைப்பை அங்கீகரிக்கவா?',
  'Approve design': 'வடிவமைப்பை அங்கீகரி',
  'Approve Design': 'வடிவமைப்பை அங்கீகரி',
  'Approved revision details': 'அங்கீகரிக்கப்பட்ட பதிப்பின் விவரங்கள்',
  'Close': 'மூடு',
  'Review, Approval & Export': 'மதிப்பாய்வு, அங்கீகாரம் மற்றும் ஏற்றுமதி',
  'Run Backend Validation': 'பின்தளச் சரிபார்ப்பை இயக்கு',
  'Refresh History': 'வரலாற்றைப் புதுப்பி',
  'Run validation before approving this design.':
      'அங்கீகரிப்பதற்கு முன் சரிபார்ப்பை இயக்கவும்.',
  'Approved Revision History': 'அங்கீகரிக்கப்பட்ட பதிப்புகளின் வரலாறு',
  'No approved revisions loaded.':
      'அங்கீகரிக்கப்பட்ட பதிப்புகள் ஏற்றப்படவில்லை.',
  'Revision details': 'பதிப்பு விவரங்கள்',
  'Create Official Export': 'அதிகாரப்பூர்வ ஏற்றுமதியை உருவாக்கு',
  'Official Second Brain Exports': 'அதிகாரப்பூர்வ Second Brain ஏற்றுமதிகள்',
  'No official export records loaded.': 'ஏற்றுமதிப் பதிவுகள் ஏற்றப்படவில்லை.',
  'Download Official ZIP': 'அதிகாரப்பூர்வ ZIP கோப்பைப் பதிவிறக்கு',
  'Open UI Studio': 'UI வடிவமைப்பு மையத்தைத் திற',
  'Select a component to edit its properties':
      'பண்புகளைத் திருத்த ஒரு கூறைத் தேர்ந்தெடுக்கவும்',
  'Component Properties': 'கூறுகளின் பண்புகள்',
  'Back to project overview': 'திட்ட மேலோட்டத்திற்குத் திரும்புக',
  'Open preview': 'முன்னோட்டத்தைத் திற',
  'Edit server requirement': 'பின்தளத் தேவையைத் திருத்து',
  'Save edit': 'திருத்தத்தைச் சேமி',
  'Accept requirement': 'தேவையை ஏற்றுக்கொள்',
  'Edit requirement': 'தேவையைத் திருத்து',
  'Reject requirement': 'தேவையை நிராகரி',
  'Clarifications': 'விளக்கங்கள்',
  'Defer requirement': 'தேவையை ஒத்திவை',
  'AI Requirements Extraction': 'AI மூலம் தேவைகளைப் பிரித்தெடுத்தல்',
  'I consent to AI processing of saved sources':
      'சேமித்த மூலங்களை AI செயலாக்க அனுமதிக்கிறேன்',
  'Clarifications & Blueprint sync': 'விளக்கங்கள் மற்றும் வடிவமைப்பு ஒத்திசைவு',
  'Extract with AI': 'AI மூலம் பிரித்தெடு',
  'Recover saved server reviews': 'சேமித்த பின்தள மதிப்பாய்வுகளை மீட்டெடு',
  'Stage for review': 'மதிப்பாய்விற்குத் தயாராக்கு',
  'Refresh server status': 'பின்தள நிலையைப் புதுப்பி',
  'Voice transcript saved as text source': 'குரல் உரை மூலமாகச் சேமிக்கப்பட்டது',
  'Voice Input': 'குரல் உள்ளீடு',
  'Select audio file': 'ஒலிக் கோப்பைத் தேர்ந்தெடு',
  'I consent to server audio processing':
      'பின்தள ஒலிச் செயலாக்கத்தை அனுமதிக்கிறேன்',
  'Transcribe audio': 'ஒலியை உரையாக மாற்று',
  'I have reviewed this transcript': 'இந்த உரையை மதிப்பாய்வு செய்துள்ளேன்',
  'Save transcript as source': 'உரையை மூலமாகச் சேமி',
  'Answer clarification': 'விளக்கக் கேள்விக்குப் பதிலளி',
  'Submit answer': 'பதிலைச் சமர்ப்பி',
  'Load clarifications': 'விளக்கங்களை ஏற்று',
  'Check Blueprint sync': 'வடிவமைப்பு ஒத்திசைவைச் சரிபார்',
  'No saved clarifications.': 'சேமித்த விளக்கங்கள் இல்லை.',
  'Awaiting answer': 'பதிலுக்காகக் காத்திருக்கிறது',
  'Answer': 'பதில்',
  'Save clarification': 'விளக்கத்தைச் சேமி',
  'Clarification answers do not automatically approve requirements.':
      'விளக்கப் பதில்கள் தேவைகளைத் தானாக அங்கீகரிக்காது.',
  'Project Members & Permissions': 'திட்ட உறுப்பினர்களும் அனுமதிகளும்',
  'Confirm': 'உறுதிப்படுத்து',
  'Owner': 'உரிமையாளர்',
  'Editor': 'திருத்துபவர்',
  'Viewer': 'பார்வையாளர்',
  'Refresh': 'புதுப்பி',
  'Add Registered Member': 'பதிவுசெய்த உறுப்பினரைச் சேர்க்கவும்',
  'Add Member': 'உறுப்பினரைச் சேர்',
  'MCP & Developer Handoff': 'MCP மற்றும் உருவாக்குநர் ஒப்படைப்பு',
  'Read-only project context': 'படிக்க மட்டும் அனுமதிக்கப்பட்ட திட்டத் தகவல்',
  'Refresh Catalog': 'பட்டியலைப் புதுப்பி',
  'Available tools': 'கிடைக்கும் கருவிகள்',
  'Prompt templates': 'வழிமுறை வார்ப்புருக்கள்',
  'Resource references': 'வளக் குறிப்புகள்',
  'Only share project data with authorized recipients.':
      'அனுமதிக்கப்பட்டவர்களுடன் மட்டும் திட்டத் தரவைப் பகிரவும்.',
  'Load account profile': 'கணக்கு விவரங்களை ஏற்று',
  'Change email address': 'மின்னஞ்சல் முகவரியை மாற்று',
  'Return to REQVIORA': 'REQVIORA-க்குத் திரும்புக',

  'Define the project vision and its users':
      'திட்டத்தின் நோக்கத்தையும் பயனர்களையும் வரையறுக்கவும்',
  'Map requirements into features and screens':
      'தேவைகளை அம்சங்களுடனும் திரைகளுடனும் இணைக்கவும்',
  'Create routes and user journeys':
      'வழிசெலுத்தல் பாதைகளையும் பயனர் பயணங்களையும் உருவாக்கவும்',
  'Choose colors, typography and branding':
      'நிறங்கள், எழுத்துருக்கள் மற்றும் பிராண்ட் தோற்றத்தைத் தேர்ந்தெடுக்கவும்',
  'Compose reusable components and layouts':
      'மீண்டும் பயன்படுத்தக்கூடிய கூறுகளையும் திரை அமைப்புகளையும் உருவாக்கவும்',
  'Configure actions and UI states': 'செயல்களையும் UI நிலைகளையும் அமைக்கவும்',
  'Create and refine AI-assisted interface designs':
      'AI உதவியுடன் இடைமுக வடிவமைப்பை உருவாக்கவும்',
  'Validate, approve and export the project':
      'திட்டத்தைச் சரிபார்த்து அங்கீகரித்து ஏற்றுமதி செய்யவும்',
  'Persistent design tokens used by the template renderer.':
      'வார்ப்புரு காட்சியாக்கத்திற்கான சேமிக்கப்பட்ட வடிவமைப்பு மதிப்புகள்.',
  'Validate the current design and manage approved revisions.':
      'வடிவமைப்பைச் சரிபார்த்து அங்கீகரிக்கப்பட்ட பதிப்புகளை நிர்வகிக்கவும்.',
  'Immutable server-approved design snapshots.':
      'மாற்ற முடியாத அங்கீகரிக்கப்பட்ட வடிவமைப்புப் பதிப்புகள்.',
  'Download archives created from approved revisions.':
      'அங்கீகரிக்கப்பட்ட பதிப்புகளின் கோப்புகளைப் பதிவிறக்கவும்.',
  'Extract suggestions from saved sources using the server AI provider.':
      'சேமித்த மூலங்களிலிருந்து AI பரிந்துரைகளைப் பிரித்தெடுக்கவும்.',
  'Upload recorded audio and review the server transcript.':
      'பதிவுசெய்த ஒலியைப் பதிவேற்றி உரையை மதிப்பாய்வு செய்யவும்.',
  'Local simulation only. Not the approved Blueprint.':
      'உள்ளூர் உருவகப்படுத்தல் மட்டுமே. அங்கீகரிக்கப்பட்ட வடிவமைப்பு அல்ல.',
  'Server-generated design. Approval is a separate action.':
      'பின்தளம் உருவாக்கிய வடிவமைப்பு. அங்கீகாரம் தனிச் செயல்.',
  'Personal workspace': 'தனிப்பட்ட பணியிடம்',
  'Design workspace': 'வடிவமைப்புப் பணியிடம்',
};
