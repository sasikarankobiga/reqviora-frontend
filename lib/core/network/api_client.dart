import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../auth/auth_session.dart';
import 'backend_connection.dart';

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
  ApiClient(this._http, {this.requestTimeout = const Duration(seconds: 60)});

  final http.Client _http;
  final Duration requestTimeout;

  Future<bool>? _refreshInFlight;
  int? _refreshGeneration;

  Future<T> _network<T>(Future<T> Function() send) async {
    backendConnection.setPhase(
      backendConnection.phase == BackendConnectionPhase.active
          ? BackendConnectionPhase.reconnecting
          : BackendConnectionPhase.connecting,
    );
    try {
      final result = await send().timeout(requestTimeout);
      backendConnection.setPhase(BackendConnectionPhase.active);
      return result;
    } on TimeoutException {
      backendConnection.setPhase(BackendConnectionPhase.unavailable);
      throw const ApiException(
        0,
        'The request timed out. Check the current status before retrying.',
      );
    } on http.ClientException {
      backendConnection.setPhase(BackendConnectionPhase.unavailable);
      throw const ApiException(
        0,
        'Cannot connect to backend. Please check your connection.',
      );
    }
  }

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

  Map<String, String> _multipartHeadersFor(String? accessToken) => {
    'Accept': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    if (isLocalDemo && !kReleaseMode) 'X-Reqviora-Local-Demo': 'true',
  };

  void _ensureSession(int generation) {
    if (authSession.generation != generation) {
      throw const ApiException(
        401,
        'The authentication session changed. Please retry.',
      );
    }
  }

  bool _canRefresh(String path, _SessionSnapshot snapshot) =>
      !path.startsWith('/api/auth/') &&
      authSession.generation == snapshot.generation &&
      authSession.authenticated &&
      snapshot.refreshToken != null;

  Future<bool> _recoverUnauthorized(
    String path,
    _SessionSnapshot snapshot,
  ) async {
    _ensureSession(snapshot.generation);

    if (!_canRefresh(path, snapshot)) {
      return false;
    }

    if (authSession.token != snapshot.accessToken) {
      return authSession.authenticated;
    }

    if (authSession.refreshToken != snapshot.refreshToken) {
      return false;
    }

    final refreshed = await _refreshOnce(snapshot);

    _ensureSession(snapshot.generation);

    return refreshed;
  }

  Future<bool> _refreshOnce(_SessionSnapshot snapshot) async {
    if (authSession.generation != snapshot.generation ||
        !authSession.authenticated ||
        snapshot.refreshToken == null) {
      return false;
    }

    if (authSession.refreshToken != snapshot.refreshToken) {
      return authSession.token != snapshot.accessToken;
    }

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

    if (currentToken == null) {
      return false;
    }

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

      if (authSession.generation != snapshot.generation) {
        return false;
      }

      if (authSession.refreshToken != currentToken) {
        return authSession.authenticated &&
            authSession.token != snapshot.accessToken;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        authSession.signOut(expired: true);
        return false;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);

      if (data is! Map) {
        return false;
      }

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
        expectedGeneration: snapshot.generation,
        expectedRefreshToken: currentToken,
        accessToken: access,
        refreshToken: refresh,
        accessExpiresAt: expires,
      );
    } on Exception {
      // Temporary network errors do not discard
      // a potentially valid authentication session.
      return false;
    }
  }

  Future<http.Response> _sendAuthenticated(
    String path,
    Future<http.Response> Function(String? accessToken) send,
  ) async {
    final snapshot = _snapshot();

    _ensureSession(snapshot.generation);

    var response = await _network(() => send(snapshot.accessToken));

    _ensureSession(snapshot.generation);

    if (response.statusCode == 401 &&
        await _recoverUnauthorized(path, snapshot)) {
      _ensureSession(snapshot.generation);

      response = await _network(() => send(authSession.token));
    }

    _ensureSession(snapshot.generation);

    return response;
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

  // GET request.
  Future<dynamic> get(String path) async {
    final response = await _sendAuthenticated(
      path,
      (accessToken) => _http.get(_uri(path), headers: _headersFor(accessToken)),
    );

    return _parse(response);
  }

  // POST request with optional idempotency key.
  Future<dynamic> post(
    String path,
    Map<String, dynamic> data, {
    String? key,
  }) async {
    final body = jsonEncode(data);

    final response = await _sendAuthenticated(
      path,
      (accessToken) => _http.post(
        _uri(path),
        headers: {
          ..._headersFor(accessToken),
          if (key != null) 'Idempotency-Key': key,
        },
        body: body,
      ),
    );

    return _parse(response);
  }

  // PUT request.
  Future<dynamic> put(String path, Map<String, dynamic> data) async {
    final body = jsonEncode(data);

    final response = await _sendAuthenticated(
      path,
      (accessToken) =>
          _http.put(_uri(path), headers: _headersFor(accessToken), body: body),
    );

    return _parse(response);
  }

  // DELETE request.
  Future<void> delete(String path) async {
    final response = await _sendAuthenticated(
      path,
      (accessToken) =>
          _http.delete(_uri(path), headers: _headersFor(accessToken)),
    );

    _parse(response);
  }

  // Document source upload.
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

    final path = '/api/projects/$projectId/documents';

    var snapshot = _snapshot();

    final generation = snapshot.generation;

    final expires = authSession.accessExpiresAt;

    if (expires != null &&
        expires.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        ) &&
        _canRefresh(path, snapshot)) {
      await _refreshOnce(snapshot);

      _ensureSession(generation);

      snapshot = _snapshot();
    }

    _ensureSession(generation);

    final request = http.MultipartRequest('POST', _uri(path));

    request.headers.addAll(_multipartHeadersFor(snapshot.accessToken));

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

  // Binary file and ZIP download.
  Future<List<int>> getBytes(String path) async {
    final response = await _sendAuthenticated(
      path,
      (accessToken) => _http.get(_uri(path), headers: _headersFor(accessToken)),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _parse(response);

      throw ApiException(response.statusCode, 'Download failed');
    }

    return response.bodyBytes;
  }

  // Voice transcription.
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

    Future<http.Response> send(String? accessToken) async {
      final request = http.MultipartRequest('POST', _uri(path));

      request.headers.addAll(_multipartHeadersFor(accessToken));

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

      final response = await _http.send(request);

      return http.Response.fromStream(response);
    }

    final response = await _sendAuthenticated(path, send);

    final result = _parse(response);

    if (result is! Map) {
      throw const FormatException('Invalid transcript response');
    }

    return Map<String, dynamic>.from(result);
  }

  // Registration email verification.
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
