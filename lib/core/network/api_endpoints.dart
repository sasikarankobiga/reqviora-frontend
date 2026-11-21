
class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refreshToken = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';

  // Current User
  static const String currentUser = '/api/users/me';

  // Project Management
  static const String projects = '/api/projects';

  static String projectById(String projectId) {
    return '/api/projects/$projectId';
  }

  static String projectOverview(String projectId) {
    return '/api/projects/$projectId/overview';
  }

  // Requirements
  static String requirements(String projectId) {
    return '/api/projects/$projectId/requirements';
  }

  // Features and Screens
  static String features(String projectId) {
    return '/api/projects/$projectId/features';
  }

  static String screens(String projectId) {
    return '/api/projects/$projectId/screens';
  }

  // Navigation
  static String navigation(String projectId) {
    return '/api/projects/$projectId/navigation';
  }
}
