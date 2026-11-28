import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/features/auth/application/auth_providers.dart';
import 'package:reqviora_frontend/features/auth/domain/authenticated_profile.dart';
import 'package:reqviora_frontend/features/auth/presentation/authenticated_identity.dart';
import 'package:reqviora_frontend/l10n/app_localizations.dart';

void main() {
  const profile = AuthenticatedProfile(
    userId: 'user-1',
    email: 'nila@example.test',
    displayName: 'நிலா தேவி',
    emailVerified: true,
  );

  tearDown(authSession.signOut);

  test('profile parser preserves Tamil and Unicode display names', () {
    final parsed = AuthenticatedProfile.fromJson({
      'userId': 'user-1',
      'email': 'nila@example.test',
      'displayName': 'நிலா தேவி',
      'emailVerified': true,
    });

    expect(parsed.displayName, 'நிலா தேவி');
    expect(parsed.initials, 'நிதே');
    expect(initialsForDisplayName('Ada Lovelace'), 'AL');
    expect(initialsForDisplayName('😀 Engineer'), '😀E');
  });

  test('all greeting periods and exact boundaries use local time', () {
    GreetingPeriod at(int hour, [int minute = 0]) =>
        greetingPeriodAt(DateTime(2026, 11, 28, hour, minute));

    expect(at(4, 59), GreetingPeriod.welcomeBack);
    expect(at(5), GreetingPeriod.morning);
    expect(at(11, 59), GreetingPeriod.morning);
    expect(at(12), GreetingPeriod.afternoon);
    expect(at(16, 59), GreetingPeriod.afternoon);
    expect(at(17), GreetingPeriod.evening);
    expect(at(20, 59), GreetingPeriod.evening);
    expect(at(21), GreetingPeriod.welcomeBack);
  });

  testWidgets('real profile name and Unicode initials render consistently', (
    tester,
  ) async {
    authSession.signIn('test-access-token');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authenticatedProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                AuthenticatedName(),
                AuthenticatedAvatar(),
                PersonalizedGreeting(now: _morning),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('நிலா தேவி'), findsOneWidget);
    expect(find.text('நிதே'), findsOneWidget);
    expect(find.text('Good morning, நிலா தேவி!'), findsOneWidget);
  });
}

DateTime _morning() => DateTime(2026, 11, 28, 5);
