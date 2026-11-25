import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/workspace/domain/draft_conflict.dart';

void main() {
  test('HTTP 409 indicates draft conflict', () {
    expect(isDraftConflict(const ApiException(409, 'Conflict')), isTrue);
  });

  test('HTTP 412 indicates stale draft token', () {
    expect(
      isDraftConflict(const ApiException(412, 'Precondition failed')),
      isTrue,
    );
  });

  test('Local stale version is detected', () {
    expect(
      isDraftConflict(StateError('The draft has changed. Reload and retry.')),
      isTrue,
    );
  });

  test('Ordinary request errors are not draft conflicts', () {
    expect(
      isDraftConflict(const ApiException(400, 'Invalid request')),
      isFalse,
    );
  });

  test('Conflict message explains reload and unsaved edits', () {
    final message = draftConflictMessage(const ApiException(409, 'Conflict'));

    expect(message, contains('Reload'));
    expect(message, contains('Unsaved edits'));
  });
}
