
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/projects/data/datasources/project_api_service.dart';

void main() {
  group('Create Project API Service Tests', () {
    test(
      'Success: sends JWT and project data, parses response',
      () async {
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://example.test',
          ),
        );

        RequestOptions? capturedRequest;

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedRequest = options;

              // Mock successful backend response.
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id':
                        '11111111-1111-4111-8111-111111111111',
                    'name': 'Student Management System',
                    'description':
                        'A system for managing student records.',
                    'ownerId': 'test-user-id',
                    'createdAt': '2026-01-01T10:00:00Z',
                    'projectType': 'Web Application',
                    'targetAudience':
                        'Students and teachers',
                    'primaryPlatform': 'web',
                  },
                ),
              );
            },
          ),
        );

        final service = ProjectApiService(dio);

        final project = await service.createProject(
          accessToken: 'mock-jwt-token',
          name: '  Student Management System  ',
          description:
              '  A system for managing student records.  ',
          projectType: 'Web Application',
          targetAudience: '  Students and teachers  ',
        );

        // Verify HTTP request.
        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.method, 'POST');
        expect(capturedRequest!.path, '/api/projects');

        // Verify JWT Authorization header.
        expect(
          capturedRequest!.headers['Authorization'],
          'Bearer mock-jwt-token',
        );

        // Verify submitted project data.
        final requestData =
            capturedRequest!.data as Map<String, dynamic>;

        expect(
          requestData['name'],
          'Student Management System',
        );

        expect(
          requestData['description'],
          'A system for managing student records.',
        );

        expect(
          requestData['projectType'],
          'Web Application',
        );

        expect(
          requestData['targetAudience'],
          'Students and teachers',
        );

        expect(
          requestData['primaryPlatform'],
          'web',
        );

        // Verify returned ProjectModel.
        expect(
          project.id,
          '11111111-1111-4111-8111-111111111111',
        );

        expect(
          project.name,
          'Student Management System',
        );

        expect(
          project.ownerId,
          'test-user-id',
        );
      },
    );

    test(
      'Failure: backend 400 response throws DioException',
      () async {
        final dio = Dio(
          BaseOptions(
            baseUrl: 'https://example.test',
          ),
        );

        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              // Mock a backend validation error.
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 400,
                    data: {
                      'message': 'Invalid project details',
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            },
          ),
        );

        final service = ProjectApiService(dio);

        await expectLater(
          service.createProject(
            accessToken: 'mock-jwt-token',
            name: 'Invalid',
            description: 'Invalid project details',
            projectType: 'Web Application',
            targetAudience: 'Students',
          ),
          throwsA(
            isA<DioException>().having(
              (error) => error.response?.statusCode,
              'HTTP status code',
              400,
            ),
          ),
        );
      },
    );
  });
}
