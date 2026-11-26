import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/app/reqviora_app.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_page.dart';
import 'package:reqviora_frontend/features/auth/presentation/account_security_pages.dart';
import 'package:reqviora_frontend/l10n/app_localizations.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(() {
    authSession.signOut();
    appRouter.go('/projects');
  });

  testWidgets('REQVIORA account recovery honors the Tamil browser locale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('ta')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: ReqvioraApp()));
    await tester.pumpAndSettle();
    appRouter.go('/forgot-password');
    await tester.pumpAndSettle();

    expect(find.byType(AccountSecurityPage), findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(find.byType(AccountSecurityPage))),
      const Locale('ta'),
    );
    expect(find.text('கடவுச்சொல்லை மறந்துவிட்டீர்களா'), findsOneWidget);
    expect(find.text('மீட்டமைப்பு இணைப்பை அனுப்பு'), findsOneWidget);
  });

  testWidgets('administration access state is available in Tamil', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('ta'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('REQVIORA நிர்வாகம்'), findsOneWidget);
    expect(
      find.text('நிர்வாகத்திற்கு உண்மையான உள்நுழைவு தேவை.'),
      findsOneWidget,
    );
  });
}
