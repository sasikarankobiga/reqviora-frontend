import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_mcp_grant_repository.dart';
import 'package:reqviora_frontend/features/administration/domain/admin_mcp_grant.dart';

const grantId = '11111111-1111-4111-8111-111111111111';
const projectId = '22222222-2222-4222-8222-222222222222';
const revisionId = '33333333-3333-4333-8333-333333333333';
const ownerId = '44444444-4444-4444-8444-444444444444';

Map<String, Object?> grant({String state = 'active'}) => <String, Object?>{
  'id': grantId,
  'projectId': projectId,
  'approvedRevisionId': revisionId,
  'ownerId': ownerId,
  'createdAt': '2026-11-20T10:00:00Z',
  'expiresAt': '2026-12-20T10:00:00Z',
  'revokedAt': state == 'revoked' ? '2026-11-21T10:00:00Z' : null,
  'revokedBy': state == 'revoked' ? ownerId : null,
  'revocationReason': state == 'revoked' ? 'Emergency response' : null,
  'state': state,
  'credential': 'must-not-be-retained',
  'secretHash': 'must-not-be-retained',
};

void main() {
  test('lists grants using only backend-supported filters', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/admin/mcp/grants');
        expect(request.url.queryParameters, containsPair('state', 'revoked'));
        expect(request.url.queryParameters, containsPair('search', 'owner'));
        expect(
          request.url.queryParameters,
          containsPair('projectId', projectId),
        );
        return http.Response(
          jsonEncode({
            'page': 2,
            'pageSize': 20,
            'total': 21,
            'items': [grant(state: 'revoked')],
          }),
          200,
        );
      }),
    );
    addTearDown(api.dispose);
    final result = await AdminMcpGrantRepository(api).list(
      page: 2,
      search: ' owner ',
      state: AdminMcpGrantState.revoked,
      projectId: projectId,
    );
    expect(result.total, 21);
    expect(result.items.single.state, AdminMcpGrantState.revoked);
    expect(
      result.items.single.toString(),
      isNot(contains('must-not-be-retained')),
    );
  });

  test('loads details without retaining credential fields', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.url.path, '/api/admin/mcp/grants/$grantId');
        return http.Response(jsonEncode(grant()), 200);
      }),
    );
    addTearDown(api.dispose);
    final item = await AdminMcpGrantRepository(api).details(grantId);
    expect(item.id, grantId);
    expect(item.revocationReason, isNull);
  });

  test(
    'revocation requires a reason and prevents duplicate requests',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final api = ApiClient(
        MockClient((request) {
          calls++;
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'reason': 'Security incident'});
          return response.future;
        }),
      );
      addTearDown(api.dispose);
      final repository = AdminMcpGrantRepository(api);
      await expectLater(repository.revoke(grantId, 'x'), throwsArgumentError);
      final first = repository.revoke(grantId, ' Security incident ');
      await expectLater(
        repository.revoke(grantId, 'Security incident'),
        throwsStateError,
      );
      response.complete(
        http.Response(jsonEncode(grant(state: 'revoked')), 200),
      );
      expect((await first).state, AdminMcpGrantState.revoked);
      expect(calls, 1);
    },
  );

  test('unauthorized response is never parsed as grant data', () async {
    final api = ApiClient(MockClient((_) async => http.Response('{}', 403)));
    addTearDown(api.dispose);
    await expectLater(
      AdminMcpGrantRepository(api).list(),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 403),
      ),
    );
  });

  test('malformed and invalid filters fail closed', () async {
    var calls = 0;
    final api = ApiClient(
      MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.dispose);
    await expectLater(
      AdminMcpGrantRepository(api).list(projectId: 'bad'),
      throwsArgumentError,
    );
    expect(calls, 0);
  });
}
