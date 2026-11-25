import 'dart:async';
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
  ApiClient(this._http, {this.requestTimeout = const Duration(seconds: 60)});

  final Duration requestTimeout;

  Future<T> _network<T>(Future<T> Function() send) async {
    try {
      return await send().timeout(requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        0,
        'The request timed out. Check the current status before retrying.',
      );
    } on http.ClientException {
      throw const ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
    }
  }

  final http.Client _http;
  Future<bool>? _refreshInFlight;
  int? _refreshGeneration;
  Uri _uri(String path) {
    final base = Uri.tryParse(apiBaseUrl);
    final target = Uri.tryParse(path);

    if (base == null ||
        !['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasFragment ||
        base.hasQuery) {
      throw const ApiException(0, 'Invalid backend configuration.');
    }

    if (target == null ||
        target.hasScheme ||
        target.hasAuthority ||
        target.hasFragment ||
        !path.startsWith('/api/') ||
        path.contains('\\') ||
        !target.path.startsWith('/api/')) {
      throw const ApiException(0, 'Invalid API request path.');
    }
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

  void _ensureSession(int generation) {
    if (authSession.generation != generation) {
      throw const ApiException(
        401,
        'The authentication session changed. Please retry.',
      );
    }
  }

  Future<bool> _refreshOnce() async {
    final generation = authSession.generation;
    final current = authSession.refreshToken;

    if (current == null) return false;

    final pending = _refreshInFlight;

    if (pending != null && _refreshGeneration == generation) {
      return pending;
    }

    final result = _exchangeRefresh(current, generation);

    _refreshInFlight = result;
    _refreshGeneration = generation;

    try {
      return await result;
    } finally {
      if (identical(_refreshInFlight, result)) {
        _refreshInFlight = null;
        _refreshGeneration = null;
      }
    }
  }

  Future<bool> _exchangeRefresh(String currentToken, int generation) async {
    try {
      final response = await _network(
        () => _http.post(
          _uri('/api/auth/refresh'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'refreshToken': currentToken}),
        ),
      );

      if (authSession.generation != generation ||
          authSession.refreshToken != currentToken) {
        return false;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        authSession.signOut();
        return false;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);

      if (data is! Map) return false;

      final access = data['accessToken'];
      final refresh = data['refreshToken'];
      final expiresValue = data['accessTokenExpiresAt'];

      if (access is! String ||
          refresh is! String ||
          expiresValue is! String ||
          access.trim().isEmpty ||
          refresh.trim().isEmpty) {
        return false;
      }

      final expires = DateTime.tryParse(expiresValue);

      if (expires == null || !expires.isAfter(DateTime.now().toUtc())) {
        return false;
      }

      return authSession.replaceRefreshedSession(
        expectedGeneration: generation,
        expectedRefreshToken: currentToken,
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: expires,
      );
    } on Exception {
      return false;
    }
  }

  Future<bool> _retryUnauthorized(
    String path,
    int generation,
    String? originalToken,
  ) async {
    _ensureSession(generation);

    if (!_canRefresh(path)) return false;

    if (authSession.token != originalToken) {
      return authSession.authenticated;
    }

    final refreshed = await _refreshOnce();

    if (authSession.generation != generation) {
      return false;
    }

    return refreshed;
  }

  dynamic _parse(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        throw ApiException(response.statusCode, 'Invalid response from server');
      }

      data = null;
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
      final generation = authSession.generation;
      final originalToken = authSession.token;
      var response = await _network(
        () => _http.get(_uri(path), headers: _headers),
      );
      _ensureSession(generation);

      if (response.statusCode == 401 &&
          await _retryUnauthorized(path, generation, originalToken)) {
        _ensureSession(generation);
        response = await _network(
          () => _http.get(_uri(path), headers: _headers),
        );
      }
      _ensureSession(generation);
      return _parse(response);
    } on http.ClientException {
      throw ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
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
      final generation = authSession.generation;
      final originalToken = authSession.token;
      var response = await _network(send);
      _ensureSession(generation);

      if (response.statusCode == 401 &&
          await _retryUnauthorized(path, generation, originalToken)) {
        _ensureSession(generation);
        response = await _network(send);
      }
      _ensureSession(generation);
      return _parse(response);
    } on http.ClientException {
      throw ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    try {
      Future<http.Response> send() =>
          _http.put(_uri(path), headers: _headers, body: jsonEncode(data));
      final generation = authSession.generation;
      final originalToken = authSession.token;
      var response = await _network(send);
      _ensureSession(generation);

      if (response.statusCode == 401 &&
          await _retryUnauthorized(path, generation, originalToken)) {
        _ensureSession(generation);
        response = await _network(send);
      }
      _ensureSession(generation);
      return _parse(response);
    } on http.ClientException {
      throw ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
    }
  }

  Future<void> delete(String path) async {
    try {
      Future<http.Response> send() =>
          _http.delete(_uri(path), headers: _headers);

      final generation = authSession.generation;
      final originalToken = authSession.token;
      var response = await _network(send);

      _ensureSession(generation);

      if (response.statusCode == 401 &&
          await _retryUnauthorized(path, generation, originalToken)) {
        _ensureSession(generation);
        response = await _network(send);
      }

      _ensureSession(generation);
      _parse(response);
    } on http.ClientException {
      throw ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
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

    final generation = authSession.generation;
    final expires = authSession.accessExpiresAt;
    if (expires != null &&
        expires.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        ) &&
        _canRefresh('/api/projects/$projectId/documents')) {
      await _refreshOnce();
    }

    _ensureSession(generation);

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

    final received = await _network(() async {
      final response = await _http.send(request);
      return http.Response.fromStream(response);
    });

    _ensureSession(generation);

    final result = _parse(received);

    if (result is! Map) {
      throw ApiException(
        received.statusCode,
        'Invalid document upload response.',
      );
    }

    return Map<String, dynamic>.from(result);
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final generation = authSession.generation;
      final originalToken = authSession.token;
      var response = await _network(
        () => _http.get(_uri(path), headers: _headers),
      );
      _ensureSession(generation);

      if (response.statusCode == 401 &&
          await _retryUnauthorized(path, generation, originalToken)) {
        _ensureSession(generation);
        response = await _network(
          () => _http.get(_uri(path), headers: _headers),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _parse(response);
        throw ApiException(response.statusCode, 'Download failed');
      }
      _ensureSession(generation);
      return response.bodyBytes;
    } on http.ClientException {
      throw ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
    }
  }

  Future<Map<String, dynamic>> transcribeAudio({
    required String projectId,
    required String filename,
    required Uint8List bytes,
    required String languageCode,
    required int durationSeconds,
    required bool consentGranted,
  }) async {
    if (!consentGranted) {
      throw ArgumentError('Voice processing consent is required');
    }

    if (!['en', 'ta', 'en-LK', 'ta-LK'].contains(languageCode)) {
      throw ArgumentError('Unsupported language');
    }

    if (bytes.isEmpty || bytes.length > 25000000) {
      throw ArgumentError('Audio must be between 1 byte and 25 MB');
    }

    if (durationSeconds < 1 || durationSeconds > 1800) {
      throw ArgumentError('Audio duration must be 1 to 1800 seconds');
    }

    final mediaType = switch (filename.split('.').last.toLowerCase()) {
      'wav' => MediaType('audio', 'wav'),
      'mp3' => MediaType('audio', 'mpeg'),
      'm4a' || 'mp4' => MediaType('audio', 'mp4'),
      'webm' => MediaType('audio', 'webm'),
      _ => throw ArgumentError('Unsupported audio format'),
    };

    final path = '/api/projects/$projectId/input-intelligence/voice/transcribe';

    Future<http.Response> send() async {
      final request = http.MultipartRequest('POST', _uri(path));

      request.headers.addAll({
        'Accept': 'application/json',
        if (authSession.token != null)
          'Authorization': 'Bearer ${authSession.token}',
        if (isLocalDemo && !kReleaseMode) 'X-Reqviora-Local-Demo': 'true',
      });

      request.fields.addAll({
        'LanguageCode': languageCode,
        'DurationSeconds': durationSeconds.toString(),
        'ConsentGranted': consentGranted.toString(),
      });

      request.files.add(
        http.MultipartFile.fromBytes(
          'Audio',
          bytes,
          filename: filename,
          contentType: mediaType,
        ),
      );

      return http.Response.fromStream(await _http.send(request));
    }

    try {
      final generation = authSession.generation;
      final originalToken = authSession.token;
      var response = await _network(send);

      _ensureSession(generation);

      if (response.statusCode == 401 &&
          await _retryUnauthorized(path, generation, originalToken)) {
        _ensureSession(generation);
        response = await _network(send);
      }

      _ensureSession(generation);
      final result = _parse(response);

      if (result is! Map) {
        throw const FormatException('Invalid transcript response');
      }

      return Map<String, dynamic>.from(result);
    } on http.ClientException {
      throw ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
    }
  }

  Future<void> requestRegistrationVerification(String accessToken) async {
    if (accessToken.trim().isEmpty) {
      throw const ApiException(401, 'Missing registration credential.');
    }

    final generation = authSession.generation;

    final response = await _network(
      () => _http.post(
        _uri('/api/account-security/email-verification/request'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(<String, dynamic>{}),
      ),
    );

    _ensureSession(generation);

    _parse(response);

    if (response.statusCode != 202 && response.statusCode != 204) {
      throw const ApiException(502, 'Unexpected email verification response.');
    }
  }

  void dispose() => _http.close();
}
