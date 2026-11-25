import '../../../core/network/api_client.dart';

/// User-friendly authentication errors.
/// Backend HTTP status codes are preserved by ApiException.
String authErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'Something went wrong. Please try again.';
  }

  switch (error.statusCode) {
    case 0:
      return 'Cannot connect to the REQVIORA server. '
          'Please check your connection or contact the administrator.';

    case 400:
    case 422:
      return 'The request could not be processed. '
          'Please review your details and try again.';

    case 401:
      return 'Sign in was unsuccessful. '
          'Please check your credentials and account status.';

    case 403:
      return 'Your account does not have permission '
          'to complete this action.';

    case 404:
      return 'The requested authentication service '
          'is unavailable. Please contact the administrator.';

    case 409:
      return 'The account request could not be completed '
          '(HTTP 409). Please contact the administrator '
          'if the problem continues.';

    case 429:
      return 'Too many requests. Please try again later.';

    default:
      if (error.statusCode >= 500) {
        return 'The authentication server encountered a problem. '
            'Please try again later.';
      }

      return 'Authentication request failed '
          '(HTTP ${error.statusCode}). Please try again.';
  }
}
