import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/administration/data/repositories/admin_repository.dart';

void main() {
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
}
