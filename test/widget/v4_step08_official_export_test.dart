import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/workspace/application/workspace_providers.dart';
import 'package:reqviora_frontend/features/workspace/domain/download_port.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

class _RecordingDownloader implements DownloadPort {
  String? filename;
  List<int>? bytes;
  int saves = 0;

  @override
  void saveZip(String name, List<int> content) {
    filename = name;
    bytes = List<int>.from(content);
    saves++;
  }
}

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';
  const validationId = '22222222-2222-4222-8222-222222222222';
  const revisionId = '33333333-3333-4333-8333-333333333333';
  const exportId = '44444444-4444-4444-8444-444444444444';
  const token = '55555555-5555-4555-8555-555555555555';

  // A valid, empty ZIP archive.
  const zipBytes = <int>[
    80, 75, 5, 6,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0,
  ];

  http.Response jsonResponse(Object body, int status) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<void> openStep08(
    WidgetTester tester, {
    required _RecordingDownloader downloader,
    required void Function() onExport,
    required void Function() onDownload,
    bool invalidZip = false,
  }) async {
    final client = MockClient((request) async {
      final path = request.url.path;

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId') {
        return jsonResponse({
          'id': projectId,
          'name': 'REQVIORA Step 08 Test',
          'primaryPlatform': 'web',
        }, 200);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/drafts/current') {
        return jsonResponse({
          'id': projectId,
          'projectId': projectId,
          'version': 1,
          'concurrencyToken': token,
          'draft': {
            'sections': {
              'identity': {'projectName': 'Test'},
              'blueprint': <String, dynamic>{},
            },
          },
        }, 200);
      }

      if (request.method == 'POST' &&
          path == '/api/projects/$projectId/blueprints/validate') {
        final body = jsonDecode(request.body) as Map;
        expect(body['expectedConcurrencyToken'], token);
        return jsonResponse({
          'id': validationId,
          'passed': true,
          'findings': [],
        }, 200);
      }

      if (request.method == 'POST' &&
          path == '/api/projects/$projectId/approvals') {
        final body = jsonDecode(request.body) as Map;
        expect(body['validationRunId'], validationId);
        expect(body['expectedConcurrencyToken'], token);
        return jsonResponse({'revisionId': revisionId}, 201);
      }

      if (request.method == 'POST' &&
          path ==
              '/api/projects/$projectId/exports/from-revision/$revisionId') {
        onExport();
        return jsonResponse({
          'exportId': exportId,
          'approvedRevisionId': revisionId,
          'archiveBytes': zipBytes.length,
        }, 201);
      }

      if (request.method == 'GET' &&
          path == '/api/projects/$projectId/exports/$exportId/download') {
        onDownload();
        return http.Response.bytes(
          invalidZip ? <int>[1, 2, 3, 4] : zipBytes,
          200,
          headers: {'content-type': 'application/zip'},
        );
      }

      return jsonResponse({
        'error': 'Unexpected request: ${request.method} $path',
      }, 500);
    });

    addTearDown(client.close);

    await tester.binding.setSurfaceSize(const Size(1300, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(ApiClient(client)),
          downloadPortProvider.overrideWithValue(downloader),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuilderAuthoringPage(
                projectId: projectId,
                step: 8,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> approve(WidgetTester tester) async {
    final validation = find.text('Run Backend Validation');
    await tester.ensureVisible(validation);
    await tester.tap(validation);
    await tester.pumpAndSettle();

    final approveButton = find.byKey(
      const ValueKey('step08-approve-button'),
    );

    await tester.ensureVisible(approveButton);
    await tester.tap(approveButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm Approval'));
    await tester.pumpAndSettle();

    expect(
      find.text('Approved revision: $revisionId'),
      findsOneWidget,
    );
  }

  testWidgets('Official export disabled before approval', (
    tester,
  ) async {
    final downloader = _RecordingDownloader();
    var exports = 0;

    await openStep08(
      tester,
      downloader: downloader,
      onExport: () => exports++,
      onDownload: () {},
    );

    final button = find.byKey(
      const ValueKey('step08-export-disabled'),
    );

    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(exports, 0);
    expect(downloader.saves, 0);
  });

  testWidgets('Approved revision downloads official ZIP', (
    tester,
  ) async {
    final downloader = _RecordingDownloader();
    var exports = 0;
    var downloads = 0;

    await openStep08(
      tester,
      downloader: downloader,
      onExport: () => exports++,
      onDownload: () => downloads++,
    );

    await approve(tester);

    final button = find.byKey(
      const ValueKey('step08-export-disabled'),
    );

    expect(
      tester.widget<OutlinedButton>(button).onPressed,
      isNotNull,
    );

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(exports, 1);
    expect(downloads, 1);
    expect(downloader.saves, 1);
    expect(downloader.bytes, zipBytes);
    expect(
      downloader.filename,
      'reqviora-$projectId-$revisionId.zip',
    );
  });

  testWidgets('Invalid backend ZIP is never saved', (
    tester,
  ) async {
    final downloader = _RecordingDownloader();
    var exports = 0;
    var downloads = 0;

    await openStep08(
      tester,
      downloader: downloader,
      onExport: () => exports++,
      onDownload: () => downloads++,
      invalidZip: true,
    );

    await approve(tester);

    final button = find.byKey(
      const ValueKey('step08-export-disabled'),
    );

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(exports, 1);
    expect(downloads, 1);
    expect(downloader.saves, 0);
    expect(
      find.textContaining('valid ZIP header'),
      findsOneWidget,
    );
  });
}