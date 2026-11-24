const String _resolvedApiBaseUrl = String.fromEnvironment(
  'REQVIORA_API_BASE_URL',
  defaultValue: String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5264',
  ),
);

const String apiBaseUrl = _resolvedApiBaseUrl;

const bool isLocalDemo = bool.fromEnvironment(
  'REQVIORA_LOCAL_DEMO',
  defaultValue: false,
);

class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = _resolvedApiBaseUrl;

  static const Duration connectionTimeout =
      Duration(seconds: 15);

  static const Duration receiveTimeout =
      Duration(seconds: 30);
}