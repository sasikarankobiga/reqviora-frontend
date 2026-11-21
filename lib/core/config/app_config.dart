
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5121',
  );

  static const Duration connectionTimeout =
      Duration(seconds: 15);

  static const Duration receiveTimeout =
      Duration(seconds: 30);
}
