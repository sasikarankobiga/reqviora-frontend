
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';

class AuthApiService {
  final Dio dio;

  AuthApiService(this.dio);

  // Register a new user
  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await dio.post(
      ApiEndpoints.register,
      data: {
        'displayName': displayName.trim(),
        'email': email.trim(),
        'password': password,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  // Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await dio.post(
      ApiEndpoints.login,
      data: {
        'email': email.trim(),
        'password': password,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  // Refresh the access token
  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await dio.post(
      ApiEndpoints.refreshToken,
      data: {
        'refreshToken': refreshToken,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  // Logout
  Future<void> logout({
    required String refreshToken,
  }) async {
    await dio.post(
      ApiEndpoints.logout,
      data: {
        'refreshToken': refreshToken,
      },
    );
  }
}

// Riverpod Provider
final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(dioProvider));
});
