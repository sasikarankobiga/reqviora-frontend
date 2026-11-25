import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  group('API network safety', () {
    test('Request timeout returns a controlled API exception', () async {
      final pending = Completer<http.Response>();

      final api = ApiClient(
        MockClient((request) => pending.future),
        requestTimeout: const Duration(milliseconds: 20),
      );

      addTearDown(api.dispose);

      await expectLater(
        api.get('/api/projects'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 0)
              .having((e) => e.message, 'message', contains('timed out')),
        ),
      );

      pending.complete(http.Response('[]', 200));
    });

    test('Connection failures hide internal network details', () async {
      final api = ApiClient(
        MockClient((request) async {
          throw http.ClientException('Internal transport information');
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        api.get('/api/projects'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 0)
              .having((e) => e.message, 'message', contains('Cannot connect'))
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('Internal transport')),
              ),
        ),
      );
    });

    test('Malformed successful JSON is rejected', () async {
      final api = ApiClient(
        MockClient((request) async {
          return http.Response('{invalid-json', 200);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        api.get('/api/projects'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Invalid response'),
          ),
        ),
      );
    });

    test('HTML gateway response preserves HTTP error status', () async {
      final api = ApiClient(
        MockClient((request) async {
          return http.Response('<html>Gateway unavailable</html>', 502);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        api.get('/api/projects'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)),
      );
    });

    test('Absolute external URLs are rejected before transport', () async {
      var calls = 0;

      authSession.signIn('private-test-token');

      final api = ApiClient(
        MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        api.get('https://example.invalid/api/projects'),
        throwsA(isA<ApiException>()),
      );

      expect(calls, 0);
    });

    test('Protocol-relative URLs cannot receive credentials', () async {
      var calls = 0;

      authSession.signIn('private-test-token');

      final api = ApiClient(
        MockClient((request) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(
        api.get('//example.invalid/api/projects'),
        throwsA(isA<ApiException>()),
      );

      expect(calls, 0);
    });

    test('Empty 204 response is accepted', () async {
      final api = ApiClient(
        MockClient((request) async {
          return http.Response('', 204);
        }),
      );

      addTearDown(api.dispose);

      expect(await api.post('/api/test', {}), isNull);
    });

    for (final status in [400, 401, 403, 409, 429, 503]) {
      test('HTTP $status is preserved as an API exception', () async {
        final api = ApiClient(
          MockClient((request) async {
            return http.Response('{"title":"Request rejected"}', status);
          }),
        );

        addTearDown(api.dispose);

        await expectLater(
          api.get('/api/projects'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', status),
          ),
        );
      });
    }
  });
}
