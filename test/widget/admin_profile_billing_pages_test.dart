import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_billing_page.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_profile_sessions_page.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/l10n/app_localizations.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';

const adminId = '11111111-1111-4111-8111-111111111111';
const sessionId = '22222222-2222-4222-8222-222222222222';
const projectId = '33333333-3333-4333-8333-333333333333';

Map<String, Object?> profile() => {
  'id': adminId,
  'email': 'admin@example.com',
  'displayName': 'Administrator',
  'emailVerified': true,
  'mfaEnabled': true,
};

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Widget page,
    Future<http.Response> Function(http.Request) handler, {
    Size size = const Size(390, 844),
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<http.Response> profileHandler(http.Request request) async {
    if (request.url.path == '/api/admin/profile') {
      return http.Response(jsonEncode(profile()), 200);
    }
    if (request.url.path.endsWith('/security')) {
      return http.Response(
        jsonEncode({
          'mfaEnabled': true,
          'emailVerified': true,
          'activeSessions': 1,
          'recentEvents': [],
        }),
        200,
      );
    }
    if (request.url.path.endsWith('/sessions')) {
      return http.Response(
        jsonEncode([
          {
            'id': sessionId,
            'createdAt': '2026-11-20T10:00:00Z',
            'expiresAt': '2026-12-20T10:00:00Z',
            'isCurrent': true,
            'refreshToken': 'never-render-session-secret',
          },
        ]),
        200,
      );
    }
    if (request.url.path.endsWith('/login-history')) {
      return http.Response('[]', 200);
    }
    if (request.method == 'DELETE') return http.Response('', 204);
    fail('Unexpected request ${request.method} ${request.url}');
  }

  testWidgets('profile page blocks unauthenticated access', (tester) async {
    await open(
      tester,
      const AdminProfileSessionsPage(),
      (_) async => fail('Unexpected request'),
    );
    expect(
      find.text('Authenticated administrator access is required.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('admin-profile-load')), findsNothing);
  });

  testWidgets(
    'current session revocation signs out only after server confirmation',
    (tester) async {
      authSession.signIn('admin-token');
      await open(tester, const AdminProfileSessionsPage(), profileHandler);
      await tester.tap(find.byKey(const ValueKey('admin-profile-load')));
      await tester.pumpAndSettle();
      expect(find.textContaining('never-render-session-secret'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('revoke-session-$sessionId')),
      );
      await tester.tap(find.byKey(const ValueKey('revoke-session-$sessionId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(authSession.authenticated, isFalse);
      expect(
        find.text('Authenticated administrator access is required.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'billing page renders separate Tamil currency metrics without secrets',
    (tester) async {
      authSession.signIn('admin-token');
      await open(
        tester,
        const AdminBillingPage(),
        (request) async {
          if (request.url.path.endsWith('/summary')) {
            return http.Response(
              jsonEncode({
                'sandbox': true,
                'accountingReport': false,
                'currencies': [
                  {
                    'currency': 'LKR',
                    'totalOrders': 1,
                    'successfulOrders': 1,
                    'pendingOrders': 0,
                    'failedOrders': 0,
                    'cancelledOrders': 0,
                    'chargebackOrders': 0,
                    'successfulOrderAmount': 1250,
                    'chargebackAmount': 0,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'page': 1,
              'pageSize': 20,
              'total': 1,
              'items': [
                {
                  'paymentId': adminId,
                  'projectId': projectId,
                  'payerId': sessionId,
                  'orderReference': 'ORDER-1',
                  'amount': 1250,
                  'currency': 'LKR',
                  'status': 'succeeded',
                  'createdAt': '2026-11-20T10:00:00Z',
                  'updatedAt': '2026-11-20T10:05:00Z',
                  'cardNumber': '4111111111111111',
                },
              ],
            }),
            200,
          );
        },
        size: const Size(1440, 900),
        locale: const Locale('ta'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-billing-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('admin-billing-load')));
      await tester.pumpAndSettle();
      expect(find.text('Sandbox அளவீடுகள்'), findsOneWidget);
      expect(find.textContaining('1250.00 LKR'), findsWidgets);
      expect(find.textContaining('4111111111111111'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
