import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/l10n/app_localizations.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';

void main() {
  Future<void> openLabels(WidgetTester tester, String language) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: supportedAppLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(
          body: Column(
            children: [
              LocalizedUiText('Undo'),
              LocalizedUiText('Approve Design'),
              LocalizedUiText('Approve design'),
              LocalizedUiText('Extract with AI'),
              LocalizedUiText('Select audio file'),
              LocalizedUiText('Unmapped example'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('English controls remain unchanged', (tester) async {
    await openLabels(tester, 'en');
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Approve Design'), findsOneWidget);
    expect(find.text('Approve design'), findsOneWidget);
  });

  testWidgets('Tamil controls are translated', (tester) async {
    await openLabels(tester, 'ta');
    expect(find.text('முந்தைய நிலைக்கு மாற்று'), findsOneWidget);
    expect(find.text('AI மூலம் பிரித்தெடு'), findsOneWidget);
    expect(find.text('ஒலிக் கோப்பைத் தேர்ந்தெடு'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('Case variants are both translated', (tester) async {
    await openLabels(tester, 'ta');
    expect(find.text('வடிவமைப்பை அங்கீகரி'), findsNWidgets(2));
  });

  testWidgets('English switching and fallback work', (tester) async {
    await openLabels(tester, 'ta');
    expect(find.text('Unmapped example'), findsOneWidget);
    await openLabels(tester, 'en');
    expect(find.text('Undo'), findsOneWidget);
  });
}
