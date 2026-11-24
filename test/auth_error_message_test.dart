import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/auth/domain/auth_error_message.dart';

void main() {
  test('Connection error is user friendly', () {
    final message = authErrorMessage(
      const ApiException(0, 'ClientException: Failed to fetch'),
    );

    expect(message, contains('Cannot connect'));
    expect(message, isNot(contains('ClientException')));
    expect(message, isNot(contains('Failed to fetch')));
  });

  test('HTTP 409 does not claim a specific backend cause', () {
    final message = authErrorMessage(
      const ApiException(
        409,
        'The requested workflow transition is not allowed.',
      ),
    );

    expect(message, contains('409'));
    expect(message, isNot(contains('already registered')));
  });

  test('Invalid credentials are handled', () {
    final message = authErrorMessage(const ApiException(401, 'Unauthorized'));

    expect(message, contains('Sign in'));
  });

  test('Server errors do not expose internal details', () {
    final message = authErrorMessage(
      const ApiException(500, 'Internal database exception'),
    );

    expect(message, contains('server'));
    expect(message, isNot(contains('database')));
  });

  test('Unknown errors have a safe fallback', () {
    expect(
      authErrorMessage(StateError('Internal detail')),
      'Something went wrong. Please try again.',
    );
  });
}
