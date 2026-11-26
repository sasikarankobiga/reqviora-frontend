import 'package:http_parser/http_parser.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../auth/auth_session.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class _SessionSnapshot {
  const _SessionSnapshot({
    required this.generation,
    required this.accessToken,
    required this.refreshToken,
  });

  final int generation;
  final String? accessToken;
  final String? refreshToken;
}

class ApiClient {
  ApiClient(this._http);
  final http.Client _http;
  Future<bool>? _refreshInFlight;
  int? _refreshGeneration;
  Uri _uri(String path) {
    final base = Uri.parse(apiBaseUrl);
    if (kReleaseMode && (isLocalDemo || base.scheme != 'https')) {
      throw const ApiException(
        0,
        'Production mode requires HTTPS and real authentication.',
      );
    }
    return base.resolve(path);
  }

  _SessionSnapshot _snapshot() => _SessionSnapshot(
    generation: authSession.generation,
    accessToken: authSession.token,
    refreshToken: authSession.refreshToken,
  );

  Map<String, String> _headersFor(String? accessToken) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    if (isLocalDemo && !kReleaseMode) 'X-Reqviora-Local-Demo': 'true',
  };

  bool _canRefresh(String path, _SessionSnapshot snapshot) =>
      !path.startsWith('/api/auth/') &&
      authSession.generation == snapshot.generation &&
      authSession.authenticated &&
      snapshot.refreshToken != null;

  Future<bool> _recoverUnauthorized(
    String path,
    _SessionSnapshot snapshot,
  ) async {
    if (!_canRefresh(path, snapshot)) return false;
    if (authSession.token != snapshot.accessToken) return true;
    if (authSession.refreshToken != snapshot.refreshToken) return false;
    return _refreshOnce(snapshot);
  }

  Future<bool> _refreshOnce(_SessionSnapshot snapshot) async {
    final pending = _refreshInFlight;
    if (pending != null && _refreshGeneration == snapshot.generation) {
      return pending;
    }
    final result = _exchangeRefresh(snapshot);
    _refreshInFlight = result;
    _refreshGeneration = snapshot.generation;
    try {
      return await result;
    } finally {
      if (identical(_refreshInFlight, result)) {
        _refreshInFlight = null;
        _refreshGeneration = null;
      }
    }
  }

  Future<bool> _exchangeRefresh(_SessionSnapshot snapshot) async {
    final currentToken = snapshot.refreshToken;
    if (currentToken == null) return false;
    try {
      final response = await _http.post(
        _uri('/api/auth/refresh'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': currentToken}),
      );
      if (authSession.generation != snapshot.generation) return false;
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (authSession.refreshToken == currentToken) {
          authSession.signOut();
        }
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(response.body);
      if (data is! Map) return false;
      final access = data['accessToken'];
      final refresh = data['refreshToken'];
      final expires = DateTime.tryParse(
        data['accessTokenExpiresAt'] is String
            ? data['accessTokenExpiresAt'] as String
            : '',
      );
      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty ||
          expires == null) {
        return false;
      }
      if (authSession.refreshToken != currentToken) {
        return authSession.generation == snapshot.generation &&
            authSession.token != snapshot.accessToken;
      }
      return authSession.refreshSession(
        expectedGeneration: snapshot.generation,
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: expires,
      );
    } on Exception {
      // Temporary network errors do not discard a potentially valid session.
      return false;
    }
  }

  dynamic _parse(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(response.statusCode, 'Invalid response from server');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          data is Map
              ? (data['code'] ?? data['title'] ?? 'Request failed')
              : 'Request failed';
      throw ApiException(
        response.statusCode,
        '$message (HTTP ${response.statusCode})',
      );
    }
    return data;
  }

  Future<dynamic> get(String path) async {
    try {
      final snapshot = _snapshot();
      var response = await _http.get(
        _uri(path),
        headers: _headersFor(snapshot.accessToken),
      );
      if (response.statusCode == 401 &&
          await _recoverUnauthorized(path, snapshot)) {
        if (authSession.generation != snapshot.generation) {
          return _parse(response);
        }
        response = await _http.get(
          _uri(path),
          headers: _headersFor(authSession.token),
        );
      }
      return _parse(response);
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Cannot connect to backend: $e');
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> data, {
    String? key,
  }) async {
    try {
      final snapshot = _snapshot();
      Future<http.Response> send(String? accessToken) => _http.post(
        _uri(path),
        headers: {
          ..._headersFor(accessToken),
          if (key != null) 'Idempotency-Key': key,
        },
        body: jsonEncode(data),
      );
      var response = await send(snapshot.accessToken);
      if (response.statusCode == 401 &&
          await _recoverUnauthorized(path, snapshot)) {
        if (authSession.generation != snapshot.generation) {
          return _parse(response);
        }
        response = await send(authSession.token);
      }
      return _parse(response);
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Cannot connect to backend: $e');
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    try {
      final snapshot = _snapshot();
      Future<http.Response> send(String? accessToken) => _http.put(
        _uri(path),
        headers: _headersFor(accessToken),
        body: jsonEncode(data),
      );
      var response = await send(snapshot.accessToken);
      if (response.statusCode == 401 &&
          await _recoverUnauthorized(path, snapshot)) {
        if (authSession.generation != snapshot.generation) {
          return _parse(response);
        }
        response = await send(authSession.token);
      }
      return _parse(response);
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Cannot connect to backend: $e');
    }
  }

  Future<Map<String, dynamic>> uploadSource(
    String projectId,
    int expectedVersion,
    String name,
    Uint8List data,
  ) async {
    if (expectedVersion < 0) {
      throw ArgumentError.value(
        expectedVersion,
        'expectedVersion',
        'Cannot be negative',
      );
    }

    final extension = name.split('.').last.toLowerCase();

    final mediaType = switch (extension) {
      'pdf' => MediaType('application', 'pdf'),
      'docx' => MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      'txt' => MediaType('text', 'plain'),
      _ =>
        throw ArgumentError.value(
          name,
          'name',
          'Only PDF, DOCX and TXT files are supported',
        ),
    };

    var snapshot = _snapshot();
    final expires = authSession.accessExpiresAt;
    if (expires != null &&
        expires.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        ) &&
        _canRefresh('/api/projects/$projectId/documents', snapshot)) {
      await _refreshOnce(snapshot);
      if (authSession.generation != snapshot.generation) {
        throw const ApiException(401, 'Session changed before upload.');
      }
      snapshot = _snapshot();
    }

    final request = http.MultipartRequest(
      'POST',
      _uri('/api/projects/$projectId/documents'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      if (snapshot.accessToken != null)
        'Authorization': 'Bearer ${snapshot.accessToken}',
      if (isLocalDemo && !kReleaseMode) 'X-Reqviora-Local-Demo': 'true',
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        data,
        filename: name,
        contentType: mediaType,
      ),
    );

    final response = await _http.send(request);
    final received = await http.Response.fromStream(response);

    return Map<String, dynamic>.from(_parse(received) as Map);
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final snapshot = _snapshot();
      var response = await _http.get(
        _uri(path),
        headers: _headersFor(snapshot.accessToken),
      );
      if (response.statusCode == 401 &&
          await _recoverUnauthorized(path, snapshot)) {
        if (authSession.generation != snapshot.generation) {
          _parse(response);
        }
        response = await _http.get(
          _uri(path),
          headers: _headersFor(authSession.token),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _parse(response);
        throw ApiException(response.statusCode, 'Download failed');
      }
      return response.bodyBytes;
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Cannot connect to backend: $e');
    }
  }

  void dispose() => _http.close();
}
