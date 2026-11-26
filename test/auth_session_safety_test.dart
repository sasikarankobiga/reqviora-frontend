import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';

void startTestSession(String name) {
  authSession.startSession(
    accessToken: '$name-access',
    refreshToken: '$name-refresh',
    accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

http.Response refreshResponse({
  Object accessToken = 'fresh-access',
  String refreshToken = 'fresh-refresh',
  bool expired = false,
}) {
  final expires = DateTime.now().toUtc().add(Duration(hours: expired ? -1 : 1));

  return http.Response(
    jsonEncode({
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': expires.toIso8601String(),
    }),
    200,
  );
}

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  group('Authentication session safety', () {
    test('Login and logout advance session generation', () {
      final initial = authSession.generation;

      startTestSession('user-a');

      expect(authSession.generation, initial + 1);

      authSession.signOut();

      expect(authSession.generation, initial + 2);
      expect(authSession.authenticated, isFalse);
    });

    test('Concurrent requests share one token refresh', () async {
      startTestSession('user-a');

      final refreshStarted = Completer<void>();
      final refreshResult = Completer<http.Response>();
      final bothRejected = Completer<void>();

      var refreshCalls = 0;
      var rejectedCalls = 0;
      var successfulCalls = 0;

      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls++;

            if (!refreshStarted.isCompleted) {
              refreshStarted.complete();
            }

            return refreshResult.future;
          }

          if (request.headers['Authorization'] == 'Bearer user-a-access') {
            rejectedCalls++;

            if (rejectedCalls == 2) {
              bothRejected.complete();
            }

            return http.Response('{}', 401);
          }

          expect(request.headers['Authorization'], 'Bearer fresh-access');

          successfulCalls++;

          return http.Response('[]', 200);
        }),
        requestTimeout: const Duration(seconds: 3),
      );

      addTearDown(api.dispose);

      final generation = authSession.generation;

      final results = Future.wait([
        api.get('/api/projects'),
        api.get('/api/projects'),
      ]);

      final verification = expectLater(results, completion(equals([[], []])));

      await bothRejected.future.timeout(const Duration(seconds: 3));

      await refreshStarted.future.timeout(const Duration(seconds: 3));

      refreshResult.complete(refreshResponse());

      await verification;

      expect(refreshCalls, 1);
      expect(rejectedCalls, 2);
      expect(successfulCalls, 2);
      expect(authSession.generation, generation);
      expect(authSession.token, 'fresh-access');
    });

    test('Old request cannot retry under a new user', () async {
      startTestSession('user-a');

      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;

      final api = ApiClient(
        MockClient((request) {
          calls++;
          requestStarted.complete();
          return response.future;
        }),
      );

      addTearDown(api.dispose);

      final pending = api.get('/api/projects');

      final verification = expectLater(pending, throwsA(isA<ApiException>()));

      await requestStarted.future;

      startTestSession('user-b');

      response.complete(http.Response('{}', 401));

      await verification;

      expect(calls, 1);
      expect(authSession.token, 'user-b-access');
    });

    test('Logout prevents an in-flight refresh restoring a session', () async {
      startTestSession('user-a');

      final refreshStarted = Completer<void>();
      final response = Completer<http.Response>();

      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshStarted.complete();
            return response.future;
          }

          return http.Response('{}', 401);
        }),
      );

      addTearDown(api.dispose);

      final pending = api.get('/api/projects');

      final verification = expectLater(pending, throwsA(isA<ApiException>()));

      await refreshStarted.future;

      authSession.signOut();

      response.complete(refreshResponse());

      await verification;

      expect(authSession.authenticated, isFalse);
      expect(authSession.token, isNull);
      expect(authSession.refreshToken, isNull);
    });

    test('Successful stale responses are rejected after user switch', () async {
      startTestSession('user-a');

      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();

      final api = ApiClient(
        MockClient((request) {
          requestStarted.complete();
          return response.future;
        }),
      );

      addTearDown(api.dispose);

      final pending = api.get('/api/projects');

      final verification = expectLater(pending, throwsA(isA<ApiException>()));

      await requestStarted.future;

      startTestSession('user-b');

      response.complete(http.Response('[{"name":"Old user project"}]', 200));

      await verification;

      expect(authSession.token, 'user-b-access');
    });

    test('Malformed refresh credentials are rejected', () async {
      startTestSession('user-a');

      var refreshCalls = 0;
      var projectCalls = 0;

      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls++;
            return refreshResponse(accessToken: 12345);
          }

          projectCalls++;

          return http.Response('{}', 401);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(api.get('/api/projects'), throwsA(isA<ApiException>()));

      expect(refreshCalls, 1);
      expect(projectCalls, 1);
      expect(authSession.token, 'user-a-access');
    });

    test('Expired refresh response cannot replace credentials', () async {
      startTestSession('user-a');

      var refreshCalls = 0;

      final api = ApiClient(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshCalls++;
            return refreshResponse(expired: true);
          }

          return http.Response('{}', 401);
        }),
      );

      addTearDown(api.dispose);

      await expectLater(api.get('/api/projects'), throwsA(isA<ApiException>()));

      expect(refreshCalls, 1);
      expect(authSession.token, 'user-a-access');
      expect(authSession.refreshToken, 'user-a-refresh');
    });
  });
}
