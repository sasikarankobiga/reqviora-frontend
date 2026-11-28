import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_export_diagnostics_repository.dart';

const jobId = '11111111-1111-4111-8111-111111111111';
const projectId = '22222222-2222-4222-8222-222222222222';
const revisionId = '33333333-3333-4333-8333-333333333333';

Map<String, Object?> job({String status = 'Failed'}) => <String, Object?>{
  'id': jobId,
  'projectId': projectId,
  'approvedRevisionId': revisionId,
  'exportRecordId': null,
  'exportType': 'SecondBrain',
  'status': status,
  'createdAt': '2026-11-20T10:00:00Z',
  'startedAt': '2026-11-20T10:00:01Z',
  'completedAt': '2026-11-20T10:00:03Z',
  'durationMilliseconds': 2000,
  'failureCode': status == 'Failed' ? 'ARCHIVE_FAILED' : null,
  'failureCategory': status == 'Failed' ? 'Archive' : null,
  'integrityStatus': status == 'Failed' ? 'Failed' : 'Verified',
  'physicalPath': r'C:\private\archive.zip',
  'stackTrace': 'private trace',
};

void main() {
  test(
    'lists diagnostics with supported filters and sanitized model',
    () async {
      final api = ApiClient(
        MockClient((request) async {
          expect(request.url.path, '/api/admin/exports/jobs');
          expect(request.url.queryParameters['status'], 'Failed');
          expect(request.url.queryParameters['projectId'], projectId);
          expect(request.url.queryParameters, contains('from'));
          return http.Response(
            jsonEncode({
              'page': 1,
              'pageSize': 20,
              'total': 1,
              'items': [job()],
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      final page = await AdminExportDiagnosticsRepository(api).list(
        status: AdminExportStatus.failed,
        projectId: projectId,
        from: DateTime.utc(2026, 11, 1),
      );
      expect(page.items.single.failureCategory, 'Archive');
      expect(page.items.single.toString(), isNot(contains('private trace')));
    },
  );

  test('uses backend summary instead of page-derived statistics', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/admin/exports/summary');
        return http.Response(
          jsonEncode({
            'total': 50,
            'successful': 40,
            'failed': 10,
            'successRate': 80.0,
            'averageDurationMilliseconds': 1234.5,
            'integrityVerified': 39,
            'integrityFailed': 1,
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final summary = await AdminExportDiagnosticsRepository(api).summary();
    expect(summary.total, 50);
    expect(summary.averageDurationMilliseconds, 1234.5);
  });

  test(
    'details parse lifecycle, integrity and sanitized failure data',
    () async {
      final api = ApiClient(
        MockClient((request) async {
          expect(request.url.path, '/api/admin/exports/jobs/$jobId');
          return http.Response(jsonEncode(job()), 200);
        }),
      );
      addTearDown(api.dispose);
      final result = await AdminExportDiagnosticsRepository(api).details(jobId);
      expect(result.durationMilliseconds, 2000);
      expect(result.integrityStatus, 'Failed');
    },
  );

  test('invalid date range and unauthorized access fail closed', () async {
    var calls = 0;
    final invalidApi = ApiClient(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(invalidApi.dispose);
    await expectLater(
      AdminExportDiagnosticsRepository(
        invalidApi,
      ).list(from: DateTime.utc(2026, 12), to: DateTime.utc(2026, 11)),
      throwsArgumentError,
    );
    expect(calls, 0);

    final deniedApi = ApiClient(
      MockClient((_) async => http.Response('{}', 401)),
    );
    addTearDown(deniedApi.dispose);
    await expectLater(
      AdminExportDiagnosticsRepository(deniedApi).summary(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 401),
      ),
    );
  });
}
