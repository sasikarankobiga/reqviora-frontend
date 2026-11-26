import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/application/auth_providers.dart';
import 'package:reqviora_frontend/features/auth/data/auth_repository.dart';
import 'package:reqviora_frontend/features/auth/presentation/account_profile_page.dart';
import 'package:reqviora_frontend/features/auth/presentation/account_security_pages.dart';

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Widget page,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final api = ApiClient(MockClient(handler));

    addTearDown(api.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository(api)),
        ],
        child: MaterialApp(home: page),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Account profile is cleared when the session changes', (
    tester,
  ) async {
    await open(tester, const AccountProfilePage(), (request) async {
      expect(request.url.path, '/api/users/me');

      return http.Response(
        jsonEncode({
          'displayName': 'Private Account',
          'email': 'private@example.com',
          'emailVerified': true,
        }),
        200,
      );
    });

    await tester.tap(find.text('Load account profile'));
    await tester.pumpAndSettle();

    expect(find.text('private@example.com'), findsOneWidget);

    authSession.signOut();
    await tester.pumpAndSettle();

    expect(find.text('private@example.com'), findsNothing);
    expect(find.text('Private Account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MFA secret and recovery codes disappear on logout', (
    tester,
  ) async {
    const secret = 'JBSWY3DPEHPK3PXP';
    const recoveryCode = 'test-recovery-code';

    await open(
      tester,
      const AccountSecurityPage(action: AccountAction.setupMfa),
      (request) async {
        expect(request.url.path, '/api/security/mfa/provision');

        return http.Response(
          jsonEncode({
            'secret': secret,
            'uri': 'otpauth://totp/REQVIORA?secret=$secret',
            'recoveryCodes': [recoveryCode],
          }),
          200,
        );
      },
    );

    await tester.tap(find.text('Start MFA setup'));
    await tester.pumpAndSettle();

    expect(find.text(secret), findsOneWidget);
    expect(find.text(recoveryCode), findsOneWidget);

    authSession.signOut();
    await tester.pumpAndSettle();

    expect(find.text(secret), findsNothing);
    expect(find.text(recoveryCode), findsNothing);
    expect(find.byKey(const ValueKey('security-otp')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
