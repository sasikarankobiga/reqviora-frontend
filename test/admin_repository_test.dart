 feature/thikal-v4-frontend-development
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';


import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
 develop
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_repository.dart';

void main() {
 feature/thikal-v4-frontend-development
  for (final section in AdminSection.values) {
    test('${section.name} uses admin contract and filters fields', () async {
      final api = ApiClient(
        MockClient((request) async {
          expect(request.method, 'POST');

          expect(request.url.path, section.path);

          expect(jsonDecode(request.body), {'code': '123456'});

          final row = {
            for (final field in section.fields) field: 'example',
            'secret': 'hidden',
          };

          final Object data =
              section.paged
                  ? {
                    'page': 1,
                    'pageSize': 20,
                    'total': 1,
                    'items': [row],
                  }
                  : section == AdminSection.roles
                  ? [row]
                  : section == AdminSection.health
                  ? {
                    'status': 'Healthy',
                    'checks': [row],
                  }
                  : row;

          if (section.paged) {
            expect(request.url.queryParameters['pageSize'], '20');
          }

          if (section.searchable) {
            expect(request.url.queryParameters['search'], 'a & b');
          }

          return http.Response(jsonEncode(data), 200);
        }),
      );

      addTearDown(api.dispose);

      final result = await AdminRepository(
        api,
      ).load(section, '123456', search: 'a & b');

      expect(result.rows.single.containsKey('secret'), isFalse);
    });
  }

  test('Invalid MFA never sends a request', () async {
    final api = ApiClient(
      MockClient((_) async {
        fail('Unexpected request');
      }),
    );

    addTearDown(api.dispose);

    await expectLater(
      AdminRepository(api).load(AdminSection.overview, '123'),
      throwsArgumentError,
    );
  });

  test('Forbidden response does not provide admin data', () async {
    final api = ApiClient(MockClient((_) async => http.Response('', 403)));

    addTearDown(api.dispose);

    await expectLater(
      AdminRepository(api).load(AdminSection.overview, '123456'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('admin search uses POST and encoded query', () async {
    final api = ApiClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/admin/users/search');
        expect(request.url.queryParameters['search'], 'a & b');
        expect(request.url.queryParameters['page'], '2');
        expect(request.body, '{"code":"123456"}');
        return http.Response('{"items":[],"total":0}', 200);
      }),
    );
    addTearDown(api.dispose);
    final data = await AdminRepository(
      api,
    ).read(AdminSection.users, '123456', page: 2, search: 'a & b');
    expect(data['total'], 0);
  });
  test('invalid code does not call API', () async {
    final api = ApiClient(
      MockClient((_) async {
        fail('Unexpected network call');
      }),
    );
    addTearDown(api.dispose);
    await expectLater(
      AdminRepository(api).read(AdminSection.overview, 'abc'),
      throwsFormatException,
    );
  });
  test('access denial is not treated as data', () async {
    final api = ApiClient(MockClient((_) async => http.Response('{}', 403)));
    addTearDown(api.dispose);
    await expectLater(
      AdminRepository(api).read(AdminSection.overview, '123456'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });
  test('malformed overview response is rejected before rendering', () async {
    final api = ApiClient(MockClient((_) async => http.Response('[]', 200)));
    addTearDown(api.dispose);
    await expectLater(
      AdminRepository(api).read(AdminSection.overview, '123456'),
      throwsFormatException,
    );
  });
  test('empty overview cannot authorize the admin console', () async {
    final api = ApiClient(MockClient((_) async => http.Response('{}', 200)));
    addTearDown(api.dispose);
    await expectLater(
      AdminRepository(api).read(AdminSection.overview, '123456'),
      throwsFormatException,
    );
  });
  test('paged response requires both items and numeric total', () async {
    final api = ApiClient(
      MockClient((_) async => http.Response('{"items":[]}', 200)),
    );
    addTearDown(api.dispose);
    await expectLater(
      AdminRepository(api).read(AdminSection.users, '123456'),
      throwsFormatException,
    );
  });
  test('paged response rejects fractional totals and malformed rows', () async {
    final responses = <String>[
      '{"items":[],"total":1.5}',
      '{"items":["private-data"],"total":1}',
    ];
    final api = ApiClient(
      MockClient((_) async => http.Response(responses.removeAt(0), 200)),
    );
    addTearDown(api.dispose);
    final repository = AdminRepository(api);
    await expectLater(
      repository.read(AdminSection.users, '123456'),
      throwsFormatException,
    );
    await expectLater(
      repository.read(AdminSection.users, '123456'),
      throwsFormatException,
    );
  });
  test('invalid filters are rejected without a network call', () async {
    final api = ApiClient(
      MockClient((_) async {
        fail('Unexpected network call');
      }),
    );
    addTearDown(api.dispose);
    final repository = AdminRepository(api);
    await expectLater(
      repository.read(AdminSection.users, '123456', page: 0),
      throwsFormatException,
    );
    await expectLater(
      repository.read(AdminSection.users, '123456', search: 'x' * 121),
      throwsFormatException,
    );
    await expectLater(
      repository.read(AdminSection.audit, '123456', statusCode: 99),
      throwsFormatException,
    );
  });
  test('field allowlists exclude sensitive content', () {
    for (final section in AdminSection.values) {
      expect(section.fields, isNot(contains('passwordHash')));
      expect(section.fields, isNot(contains('blueprintJson')));
      expect(section.fields, isNot(contains('refreshToken')));
    }
  });
 develop
}
