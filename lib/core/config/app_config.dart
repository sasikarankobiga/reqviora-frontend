const apiBaseUrl = String.fromEnvironment(
  'REQVIORA_API_BASE_URL', defaultValue: 'http://127.0.0.1:5264');
const isLocalDemo = bool.fromEnvironment('REQVIORA_LOCAL_DEMO', defaultValue: false);
