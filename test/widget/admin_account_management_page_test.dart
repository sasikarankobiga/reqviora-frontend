import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_account_repository.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_account_management_page.dart';

void main() {
  const actorId = '11111111-1111-4111-8111-111111111111';
  const userId = '22222222-2222-4222-8222-222222222222';

  late List<http.Request> requests;

  setUp(() {
    authSession.signOut();
    requests = [];
  });

  tearDown(() {
    authSession.signOut();
  });

  Map<String, dynamic> account(String id) => {
    'id': id,
    'email': 'user@example.com',
    'displayName': 'Example User',
    'role': 'User',
    'isDisabled': false,
    'emailVerified': true,
    'mfaEnabled': true,
  };

  Future<void> open(
    WidgetTester tester, {
    bool enabled = true,
    bool authenticated = true,
    bool denied = false,
    bool empty = false,
    bool self = false,
  }) async {
    if (authenticated) {
      authSession.signIn('widget-test-token');
    }

    final api = ApiClient(
      MockClient((request) async {
        requests.add(request);

        if (denied) {
          return http.Response(
            '{"title":"Forbidden"}',
            403,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode({
            'page': 1,
            'pageSize': 20,
            'total': empty ? 0 : 1,
            'items': empty ? [] : [account(self ? actorId : userId)],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAccountManagementPage(
          repository: AdminAccountRepository(api),
          actorId: actorId,
          availableRoles: const ['User', 'Administrator'],
          integrationEnabled: enabled,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> load(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('admin-account-load'));

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Integration disabled by default configuration', (tester) async {
    await open(tester, enabled: false);

    expect(find.text('Admin integration is unavailable.'), findsOneWidget);

    expect(requests, isEmpty);
    expect(find.text('Load accounts'), findsNothing);
  });

  testWidgets('Unauthenticated users cannot load accounts', (tester) async {
    await open(tester, authenticated: false);

    expect(find.text('Admin integration is unavailable.'), findsOneWidget);

    expect(requests, isEmpty);
  });

  testWidgets('Authenticated integration can load accounts', (tester) async {
    await open(tester);
    await load(tester);

    expect(requests.length, 1);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/admin/users');
    expect(find.text('Example User'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('Permission denial is safely displayed', (tester) async {
    await open(tester, denied: true);
    await load(tester);

    expect(find.text('Permission denied.'), findsOneWidget);
    expect(find.text('Example User'), findsNothing);
  });

  testWidgets('Empty account list is handled', (tester) async {
    await open(tester, empty: true);
    await load(tester);

    expect(find.text('No accounts found.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Self-management controls are disabled', (tester) async {
    await open(tester, self: true);
    await load(tester);

    final disable = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Disable'),
    );

    final role = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Change role'),
    );

    expect(disable.onPressed, isNull);
    expect(role.onPressed, isNull);
  });

  testWidgets('Logout clears previously loaded account data', (tester) async {
    await open(tester);
    await load(tester);

    expect(find.text('Example User'), findsOneWidget);

    authSession.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Example User'), findsNothing);
    expect(find.text('Admin integration is unavailable.'), findsOneWidget);
  });

  testWidgets('Narrow layout renders without overflow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await open(tester);
    await load(tester);

    expect(tester.takeException(), isNull);
  });

  Future<void> openDisableDialog(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, 'Disable');

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('Disable requires an explicit reason', (tester) async {
    await open(tester);
    await load(tester);
    await openDisableDialog(tester);

    expect(find.text('Disable account?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a reason.'), findsOneWidget);
    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelling account disable sends no mutation', (tester) async {
    await open(tester);
    await load(tester);
    await openDisableDialog(tester);

    await tester.enterText(find.byType(TextFormField).last, 'Test reason');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Disable account?'), findsNothing);
    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Logout invalidates pending account confirmation', (
    tester,
  ) async {
    await open(tester);
    await load(tester);
    await openDisableDialog(tester);

    await tester.enterText(find.byType(TextFormField).last, 'Test reason');

    authSession.signOut();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(requests.where((request) => request.method == 'PUT'), isEmpty);
    expect(find.text('Admin integration is unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
