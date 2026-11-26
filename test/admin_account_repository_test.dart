import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_account_repository.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';
  const actorId = '22222222-2222-4222-8222-222222222222';

  AdminAccountRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final api = ApiClient(MockClient(handler));
    addTearDown(api.dispose);
    return AdminAccountRepository(api);
  }

  Map<String, dynamic> account({
    bool disabled = false,
    String role = 'User',
    String id = userId,
  }) => {
    'id': id,
    'email': 'user@example.com',
    'displayName': 'Example User',
    'role': role,
    'isDisabled': disabled,
    'emailVerified': true,
    'mfaEnabled': false,
  };

  http.Response response(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('Searches accounts using the approved query shape', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/admin/users');
      expect(request.url.queryParameters, {
        'page': '1',
        'pageSize': '20',
        'status': 'disabled',
        'search': 'example',
      });

      return response({
        'page': 1,
        'pageSize': 20,
        'total': 1,
        'items': [account(disabled: true)],
      });
    });

    final result = await repo.getUsers(
      status: AdminAccountStatus.disabled,
      search: ' example ',
    );

    expect(result.total, 1);
    expect(result.items.single.isDisabled, isTrue);
  });

  test('Disables an account with a valid reason', () async {
    final repo = repository((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/admin/users/$userId/status');
      expect(jsonDecode(request.body), {
        'disabled': true,
        'reason': 'Policy violation',
      });

      return response(account(disabled: true));
    });

    final result = await repo.setStatus(
      userId: userId,
      actorId: actorId,
      disabled: true,
      reason: ' Policy violation ',
    );

    expect(result.isDisabled, isTrue);
  });

  test('Enables an account', () async {
    final repo = repository((request) async {
      expect(jsonDecode(request.body), {'disabled': false, 'reason': null});

      return response(account());
    });

    final result = await repo.setStatus(
      userId: userId,
      actorId: actorId,
      disabled: false,
    );

    expect(result.isDisabled, isFalse);
  });

  test('Rejects disabling without a reason', () async {
    final repo = repository((request) async {
      fail('Invalid mutation must not reach the server');
    });

    await expectLater(
      repo.setStatus(userId: userId, actorId: actorId, disabled: true),
      throwsArgumentError,
    );
  });

  test('Rejects self-disable operations', () async {
    final repo = repository((request) async {
      fail('Self-management must not reach the server');
    });

    await expectLater(
      repo.setStatus(
        userId: userId,
        actorId: userId,
        disabled: true,
        reason: 'Test',
      ),
      throwsArgumentError,
    );
  });

  test('Updates account role', () async {
    final repo = repository((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/admin/users/$userId/role');
      expect(jsonDecode(request.body), {'role': 'User'});

      return response(account());
    });

    final result = await repo.setRole(
      userId: userId,
      actorId: actorId,
      role: 'User',
    );

    expect(result.role, 'User');
  });

  test('Rejects self-role modification', () async {
    final repo = repository((request) async {
      fail('Self-role modification must not reach the server');
    });

    await expectLater(
      repo.setRole(userId: userId, actorId: userId, role: 'User'),
      throwsArgumentError,
    );
  });

  test('Rejects malformed account data', () {
    expect(
      () => AdminAccount.fromJson({'id': 'invalid'}),
      throwsFormatException,
    );
  });

  test('Preserves server authorization failure', () async {
    final repo = repository((request) async {
      return response({'title': 'Forbidden'}, 403);
    });

    await expectLater(
      repo.getUsers(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Rejects mismatched account mutation response', () async {
    final repo = repository((request) async {
      return response(account(id: actorId));
    });

    await expectLater(
      repo.setRole(userId: userId, actorId: actorId, role: 'User'),
      throwsFormatException,
    );
  });
}
