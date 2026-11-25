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

class ApiClient {
  ApiClient(this._http);
  final http.Client _http;
  Future<bool>? _refreshInFlight;
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

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (authSession.token != null)
      'Authorization': 'Bearer ${authSession.token}',
    if (isLocalDemo && !kReleaseMode) 'X-Reqviora-Local-Demo': 'true',
  };
  bool _canRefresh(String path) =>
      !path.startsWith('/api/auth/') &&
      authSession.authenticated &&
      authSession.refreshToken != null;

  Future<bool> _refreshOnce() async {
    final current = authSession.refreshToken;
    if (current == null) return false;
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final result = _exchangeRefresh(current);
    _refreshInFlight = result;
    try {
      return await result;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _exchangeRefresh(String currentToken) async {
    try {
      final response = await _http.post(
        _uri('/api/auth/refresh'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': currentToken}),
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (authSession.refreshToken == currentToken) authSession.signOut();
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(response.body);
      if (data is! Map) return false;
      final access = data['accessToken']?.toString() ?? '';
      final refresh = data['refreshToken']?.toString() ?? '';
      final expires = DateTime.tryParse(data['accessTokenExpiresAt']?.toString() ?? '');
      if (access.isEmpty || refresh.isEmpty || expires == null) return false;
      if (authSession.refreshToken != currentToken) return authSession.authenticated;
      authSession.startSession(
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: expires,
      );
      return true;
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
      var response = await _http.get(_uri(path), headers: _headers);
      if (response.statusCode == 401 && _canRefresh(path) && await _refreshOnce()) {
        response = await _http.get(_uri(path), headers: _headers);
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
      Future<http.Response> send() => _http.post(
            _uri(path),
            headers: {..._headers, if (key != null) 'Idempotency-Key': key},
            body: jsonEncode(data),
          );
      var response = await send();
      if (response.statusCode == 401 && _canRefresh(path) && await _refreshOnce()) {
        response = await send();
      }
      return _parse(response);
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Cannot connect to backend: $e');
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    try {
      Future<http.Response> send() => _http.put(
            _uri(path), headers: _headers, body: jsonEncode(data));
      var response = await send();
      if (response.statusCode == 401 && _canRefresh(path) && await _refreshOnce()) {
        response = await send();
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

    final expires = authSession.accessExpiresAt;
    if (expires != null &&
        expires.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 30))) &&
        _canRefresh('/api/projects/$projectId/documents')) {
      await _refreshOnce();
    }

    final request = http.MultipartRequest(
      'POST',
      _uri('/api/projects/$projectId/documents'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      if (authSession.token != null)
        'Authorization': 'Bearer ${authSession.token}',
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
      var response = await _http.get(_uri(path), headers: _headers);
      if (response.statusCode == 401 && _canRefresh(path) && await _refreshOnce()) {
        response = await _http.get(_uri(path), headers: _headers);
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
