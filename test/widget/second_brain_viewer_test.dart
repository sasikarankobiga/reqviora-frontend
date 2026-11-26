import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/second_brain/data/repositories/second_brain_repository.dart';
import 'package:reqviora_frontend/features/second_brain/domain/second_brain_package.dart';
import 'package:reqviora_frontend/features/second_brain/presentation/widgets/second_brain_viewer.dart';

import '../second_brain_package_test.dart' as fixture;

const projectId = fixture.projectId;
const revisionId = fixture.revisionId;
const exportId = '44444444-4444-4444-8444-444444444444';

void main() {
  setUp(() => authSession.signIn('test-session'));
  tearDown(authSession.signOut);

  Future<void> open(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) handler,
  ) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      MockClient((request) {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-session');

        return handler(request);
      }),
    );

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecondBrainViewer(
            projectId: projectId,
            repository: SecondBrainRepository(api),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  http.Response jsonResponse(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> metadata(List<int> bytes, {bool invalidHash = false}) =>
      {
        'exportId': exportId,
        'approvedRevisionId': revisionId,
        'generatorVersion': '1.0.0',
        'createdAt': '2026-11-25T12:00:00Z',
        'archiveBytes': bytes.length,
        'archiveSha256':
            invalidHash
                ? List.filled(64, '0').join()
                : SecondBrainPackage.hash(bytes),
      };

  Future<void> loadExports(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('second-brain-load')));
    await tester.pumpAndSettle();
  }

  Future<void> openPackage(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('second-brain-open-$exportId')));
    await tester.pumpAndSettle();
  }

  testWidgets('Loads and opens verified official documentation', (
    tester,
  ) async {
    final bytes = fixture.createPackage();
    final calls = <String>[];

    await open(tester, (request) async {
      final path = request.url.path;
      calls.add(path);

      if (path == '/api/projects/$projectId/exports') {
        return jsonResponse([metadata(bytes)]);
      }

      if (path == '/api/projects/$projectId/exports/$exportId') {
        return jsonResponse(metadata(bytes));
      }

      expect(path, '/api/projects/$projectId/exports/$exportId/download');

      return http.Response.bytes(
        bytes,
        200,
        headers: {'content-type': 'application/zip'},
      );
    });

    await loadExports(tester);
    await openPackage(tester);

    expect(calls.length, 3);
    expect(find.text('Package integrity verified'), findsOneWidget);
    expect(find.text('20 documents'), findsOneWidget);

    final content = tester.widget<SelectableText>(
      find.byKey(const ValueKey('second-brain-content')),
    );

    expect(content.data, contains('Approved project document'));

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('second-brain-document')),
    );

    expect(dropdown.items!.length, 20);

    dropdown.onChanged!('project.json');
    await tester.pumpAndSettle();

    final jsonContent = tester.widget<SelectableText>(
      find.byKey(const ValueKey('second-brain-content')),
    );

    expect(jsonDecode(jsonContent.data!)['revisionId'], revisionId);

    authSession.signOut();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('second-brain-content')), findsNothing);

    expect(find.text('20 documents'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rejects invalid package integrity', (tester) async {
    final bytes = fixture.createPackage();

    await open(tester, (request) async {
      final path = request.url.path;

      if (path.endsWith('/download')) {
        return http.Response.bytes(bytes, 200);
      }

      if (path.endsWith('/exports')) {
        return jsonResponse([metadata(bytes)]);
      }

      return jsonResponse(metadata(bytes, invalidHash: true));
    });

    await loadExports(tester);
    await openPackage(tester);

    expect(
      find.text('Package integrity or format verification failed.'),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('second-brain-content')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Permission denial does not expose diagnostics', (tester) async {
    await open(tester, (request) async {
      return jsonResponse({'title': 'Private authorization diagnostic'}, 403);
    });

    await loadExports(tester);

    expect(
      find.text('Only authorized project owners can access official exports.'),
      findsOneWidget,
    );

    expect(find.text('Private authorization diagnostic'), findsNothing);

    expect(find.byKey(const ValueKey('second-brain-content')), findsNothing);
  });

  testWidgets('Empty export history shows creation guidance', (tester) async {
    await open(tester, (request) async {
      return jsonResponse([]);
    });

    await loadExports(tester);

    expect(
      find.text('No official exports found. Create an export in Step 08.'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
}
