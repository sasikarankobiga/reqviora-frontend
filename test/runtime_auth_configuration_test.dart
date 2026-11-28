import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/config/app_config.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  test('real authentication is the default runtime configuration', () {
    expect(isLocalDemo, isFalse);
    expect(authSession.authenticated, isFalse);
    expect(authSession.token, isNull);
    expect(authSession.refreshToken, isNull);
  });

  test(
    'provider failure cannot create a simulated authenticated session',
    () async {
      final api = ApiClient(
        MockClient(
          (_) async => throw http.ClientException('Backend unavailable'),
        ),
      );
      addTearDown(api.dispose);

      await expectLater(
        api.post('/api/auth/login', const {
          'email': 'user@example.com',
          'password': 'StrongPassword123',
        }),
        throwsA(isA<ApiException>()),
      );

      expect(authSession.authenticated, isFalse);
      expect(authSession.token, isNull);
      expect(authSession.refreshToken, isNull);
    },
  );
}
