import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/l10n/app_localizations.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';

void main() {
  tearDown(() {
    resetAppLocalePreference();
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: appLocale,
        builder:
            (context, locale, _) => MaterialApp(
              locale: locale,
              supportedLocales: supportedAppLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder:
                      (context) => Column(
                        children: [
                          const LanguageSwitcher(),
                          Text(
                            uiText(
                              context,
                              'Welcome back',
                              '\u0BA8\u0BB2\u0BCD\u0BB5\u0BB0\u0BB5\u0BC1',
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('English is the default language', (tester) async {
    appLocale.value = const Locale('en');

    await openApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Tamil language updates the visible UI', (tester) async {
    appLocale.value = const Locale('ta');

    await openApp(tester);

    expect(find.text('Welcome back'), findsNothing);
    expect(
      find.text('\u0BA8\u0BB2\u0BCD\u0BB5\u0BB0\u0BB5\u0BC1'),
      findsOneWidget,
    );
  });

  testWidgets('Language switcher changes locale', (tester) async {
    appLocale.value = const Locale('en');

    await openApp(tester);

    await tester.tap(find.byKey(const ValueKey('app-language-switcher')));

    await tester.pumpAndSettle();

    final item = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<String> && widget.value == 'ta',
    );

    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(appLocale.value.languageCode, 'ta');
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('English can be restored', (tester) async {
    appLocale.value = const Locale('ta');

    await openApp(tester);

    await tester.tap(find.byKey(const ValueKey('app-language-switcher')));

    await tester.pumpAndSettle();

    final item = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<String> && widget.value == 'en',
    );

    await tester.tap(item);
    await tester.pumpAndSettle();

    expect(appLocale.value.languageCode, 'en');
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
