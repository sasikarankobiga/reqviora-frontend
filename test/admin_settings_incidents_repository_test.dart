import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_settings_incidents_repository.dart';
import 'package:reqviora_frontend/features/administration/domain/admin_settings_incidents.dart';

const id = '87d7a096-af02-4ec3-98ae-51f313a02111',
    actor = '8bcdd3d4-40f9-4f26-8078-f4ab58122111',
    token = '35a50dca-d0c8-4e24-8aab-a988ba532111';
Map<String, Object?> setting({int revision = 2, int value = 1000}) => {
  'key': documentUploadSettingKey,
  'value': value,
  'revision': revision,
  'minimum': 1,
  'maximum': 25000000,
};
Map<String, Object?> incident({
  String status = 'Open',
  String priority = 'High',
}) => {
  'id': id,
  'reference': 'INC-20261128-ABC',
  'category': 'AI queue',
  'priority': priority,
  'status': status,
  'reporterId': actor,
  'assignedAdminId': null,
  'correlationId': 'corr-1',
  'resolutionNotes': null,
  'createdAt': '2026-11-28T01:00:00Z',
  'updatedAt': '2026-11-28T02:00:00Z',
  'resolvedAt': null,
  'closedAt': null,
  'concurrencyToken': token,
};
void main() {
  setUp(
    () => authSession.startSession(
      accessToken: 'a',
      refreshToken: 'r',
      accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
  );
  tearDown(authSession.signOut);
  test('parses only allowlisted platform setting and history', () async {
    final api = ApiClient(
      MockClient(
        (r) async =>
            r.url.path.endsWith('/history')
                ? http.Response(
                  jsonEncode([
                    {
                      'revision': 2,
                      'previousValue': 900,
                      'value': 1000,
                      'changedBy': actor,
                      'changedAt': '2026-11-28T01:00:00Z',
                      'reason': 'Capacity update',
                      'rolledBackTo': null,
                    },
                  ]),
                  200,
                )
                : http.Response(jsonEncode([setting()]), 200),
      ),
    );
    addTearDown(api.dispose);
    final repo = AdminSettingsIncidentsRepository(api);
    expect((await repo.settings()).single.revision, 2);
    expect((await repo.settingHistory()).single.reason, 'Capacity update');
  });
  test('update and rollback send reasons and concurrency revisions', () async {
    var calls = 0;
    final api = ApiClient(
      MockClient((r) async {
        calls++;
        final body = jsonDecode(r.body) as Map;
        if (r.method == 'PUT') {
          expect(body['expectedRevision'], 2);
          expect(body['reason'], 'Approved change');
        } else {
          expect(body['targetRevision'], 1);
          expect(body['expectedRevision'], 3);
        }
        return http.Response(jsonEncode(setting(revision: calls + 2)), 200);
      }),
    );
    addTearDown(api.dispose);
    final repo = AdminSettingsIncidentsRepository(api);
    await repo.updateSetting(
      value: 1200,
      expectedRevision: 2,
      reason: 'Approved change',
    );
    await repo.rollbackSetting(
      targetRevision: 1,
      expectedRevision: 3,
      reason: 'Restore stable limit',
    );
    expect(calls, 2);
  });
  test(
    'invalid setting values, reasons and stale targets stop before HTTP',
    () async {
      var calls = 0;
      final api = ApiClient(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.dispose);
      final repo = AdminSettingsIncidentsRepository(api);
      expect(
        () => repo.updateSetting(value: 1, expectedRevision: 0, reason: 'x'),
        throwsArgumentError,
      );
      expect(
        () => repo.rollbackSetting(
          targetRevision: 3,
          expectedRevision: 3,
          reason: 'valid reason',
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );
  test('incident directory uses backend filters and parses summary', () async {
    final api = ApiClient(
      MockClient((r) async {
        if (r.url.path.endsWith('/summary'))
          return http.Response(
            jsonEncode({
              'open': 1,
              'inProgress': 0,
              'resolved': 0,
              'closed': 0,
              'critical': 0,
              'unassigned': 1,
              'total': 1,
            }),
            200,
          );
        expect(r.url.queryParameters['priority'], 'High');
        return http.Response(
          jsonEncode({
            'items': [incident()],
            'page': 1,
            'pageSize': 20,
            'total': 1,
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final result = await AdminSettingsIncidentsRepository(
      api,
    ).incidents(priority: IncidentPriority.high);
    expect(result.$1.items.single.status, IncidentStatus.open);
    expect(result.$2.total, 1);
  });
  test('incident status and assignment preserve concurrency token', () async {
    var calls = 0;
    final api = ApiClient(
      MockClient((r) async {
        calls++;
        final body = jsonDecode(r.body) as Map;
        expect(body['expectedConcurrencyToken'], token);
        return http.Response(
          jsonEncode(incident(status: calls == 1 ? 'Resolved' : 'Open')),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final repo = AdminSettingsIncidentsRepository(api);
    final item = IncidentDetails.fromJson(incident());
    await repo.changeStatus(
      item,
      IncidentStatus.resolved,
      resolutionNotes: 'Service restored',
    );
    await repo.assign(item, actor);
    expect(calls, 2);
  });
  test(
    'secret markers and unsupported lifecycle values are rejected',
    () async {
      final api = ApiClient(MockClient((_) async => http.Response('{}', 200)));
      addTearDown(api.dispose);
      final repo = AdminSettingsIncidentsRepository(api);
      expect(
        () => repo.createIncident(
          category: 'password=secret',
          priority: IncidentPriority.critical,
        ),
        throwsArgumentError,
      );
      expect(
        () => IncidentDetails.fromJson(incident(status: 'Deleted')),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => repo.changeStatus(
          IncidentDetails.fromJson(incident()),
          IncidentStatus.resolved,
          resolutionNotes: 'api_key=hidden',
        ),
        throwsArgumentError,
      );
    },
  );
}
