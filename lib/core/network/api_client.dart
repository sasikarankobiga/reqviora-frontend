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
      return _parse(await _http.get(_uri(path), headers: _headers));
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
      return _parse(
        await _http.post(
          _uri(path),
          headers: {..._headers, if (key != null) 'Idempotency-Key': key},
          body: jsonEncode(data),
        ),
      );
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Cannot connect to backend: $e');
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    try {
      return _parse(
        await _http.put(_uri(path), headers: _headers, body: jsonEncode(data)),
      );
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
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/projects/$projectId/sources/upload'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      if (authSession.token != null)
        'Authorization': 'Bearer ${authSession.token}',
      if (isLocalDemo && !kReleaseMode) 'X-Reqviora-Local-Demo': 'true',
    });
    request.fields['expectedVersion'] = '$expectedVersion';
    request.files.add(
      http.MultipartFile.fromBytes('file', data, filename: name),
    );
    final response = await _http.send(request);
    final received = await http.Response.fromStream(response);
    return Map<String, dynamic>.from(_parse(received) as Map);
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final response = await _http.get(_uri(path), headers: _headers);
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
