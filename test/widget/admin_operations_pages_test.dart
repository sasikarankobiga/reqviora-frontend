import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_export_diagnostics_page.dart';
import 'package:reqviora_frontend/features/administration/presentation/pages/admin_mcp_grants_page.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/l10n/app_localizations.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';

const grantId = '11111111-1111-4111-8111-111111111111';
const projectId = '22222222-2222-4222-8222-222222222222';
const revisionId = '33333333-3333-4333-8333-333333333333';
const ownerId = '44444444-4444-4444-8444-444444444444';

Map<String, Object?> grant() => <String, Object?>{
  'id': grantId,
  'projectId': projectId,
  'approvedRevisionId': revisionId,
  'ownerId': ownerId,
  'createdAt': '2026-11-20T10:00:00Z',
  'expiresAt': '2026-12-20T10:00:00Z',
  'revokedAt': null,
  'revokedBy': null,
  'revocationReason': null,
  'state': 'active',
  'credential': 'never-render-this-credential',
};

Map<String, Object?> job() => <String, Object?>{
  'id': grantId,
  'projectId': projectId,
  'approvedRevisionId': revisionId,
  'exportRecordId': null,
  'exportType': 'SecondBrain',
  'status': 'Succeeded',
  'createdAt': '2026-11-20T10:00:00Z',
  'startedAt': '2026-11-20T10:00:01Z',
  'completedAt': '2026-11-20T10:00:03Z',
  'durationMilliseconds': 2000,
  'failureCode': null,
  'failureCategory': null,
  'integrityStatus': 'Verified',
  'physicalPath': r'C:\private\export.zip',
};

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Widget page,
    Future<http.Response> Function(http.Request) handler, {
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
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

  testWidgets('unauthenticated users cannot access admin operations', (
    tester,
  ) async {
    await open(
      tester,
      const AdminMcpGrantsPage(),
      (_) async => fail('Unexpected request'),
    );
    expect(
      find.text('Authenticated administrator access is required.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mcp-admin-load')), findsNothing);
  });

  testWidgets('MCP directory renders authorized metadata without credentials', (
    tester,
  ) async {
    authSession.signIn('admin-token');
    await open(tester, const AdminMcpGrantsPage(), (request) async {
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'page': 1,
          'pageSize': 20,
          'total': 1,
          'items': [grant()],
        }),
        200,
      );
    });
    await tester.tap(find.byKey(const ValueKey('mcp-admin-load')));
    await tester.pumpAndSettle();
    expect(find.textContaining(projectId), findsWidgets);
    expect(find.textContaining('never-render-this-credential'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export page uses backend summary and supports Tamil', (
    tester,
  ) async {
    authSession.signIn('admin-token');
    await open(
      tester,
      const AdminExportDiagnosticsPage(),
      (request) async {
        if (request.url.path.endsWith('/summary')) {
          return http.Response(
            jsonEncode({
              'total': 1,
              'successful': 1,
              'failed': 0,
              'successRate': 100,
              'averageDurationMilliseconds': 2000,
              'integrityVerified': 1,
              'integrityFailed': 0,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'page': 1,
            'pageSize': 20,
            'total': 1,
            'items': [job()],
          }),
          200,
        );
      },
      locale: const Locale('ta'),
      size: const Size(1440, 900),
    );
    expect(find.text('ஏற்றுமதி பணி கண்டறிதல்'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('export-admin-load')));
    await tester.pumpAndSettle();
    expect(find.text('SecondBrain'), findsNothing);
    expect(find.textContaining('Succeeded'), findsOneWidget);
    expect(find.textContaining(r'C:\private\export.zip'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
