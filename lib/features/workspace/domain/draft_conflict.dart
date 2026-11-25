import '../../../core/network/api_client.dart';

bool isDraftConflict(Object error) {
  if (error is ApiException) {
    return error.statusCode == 409 || error.statusCode == 412;
  }

  if (error is StateError) {
    final message = error.message.toString().toLowerCase();

    return message.contains('draft has changed') ||
        message.contains('workspace has changed') ||
        message.contains('concurrency') ||
        message.contains('stale');
  }

  return false;
}

String draftConflictMessage(Object error) {
  if (!isDraftConflict(error)) {
    return error.toString();
  }

  return 'This project draft was updated elsewhere. '
      'Reload the latest draft to review the changes. '
      'Unsaved edits will need to be entered again.';
}
