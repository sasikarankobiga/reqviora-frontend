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
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (authSession.refreshToken == currentToken) authSession.signOut();
        return false;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final data = jsonDecode(response.body);
      if (data is! Map) return false;
      final access = data['accessToken']?.toString() ?? '';
      final refresh = data['refreshToken']?.toString() ?? '';
      final expires = DateTime.tryParse(
        data['accessTokenExpiresAt']?.toString() ?? '',
      );
      if (access.isEmpty || refresh.isEmpty || expires == null) return false;
      if (authSession.refreshToken != currentToken) {
        return authSession.authenticated;
      }
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
      var response = await _network(
        () => _http.get(_uri(path), headers: _headers),
      );
      if (response.statusCode == 401 &&
          _canRefresh(path) &&
          await _refreshOnce()) {
        response = await _network(
          () => _http.get(_uri(path), headers: _headers),
        );
      }
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
      var response = await _network(send);
      if (response.statusCode == 401 &&
          _canRefresh(path) &&
          await _refreshOnce()) {
        response = await _network(send);
      }
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
      var response = await _network(send);
      if (response.statusCode == 401 &&
          _canRefresh(path) &&
          await _refreshOnce()) {
        response = await _network(send);
      }
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

      var response = await _network(send);

      if (response.statusCode == 401 &&
          _canRefresh(path) &&
          await _refreshOnce()) {
        response = await _network(send);
      }

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

    final expires = authSession.accessExpiresAt;
    if (expires != null &&
        expires.isBefore(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        ) &&
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

    final received = await _network(() async {
      final response = await _http.send(request);
      return http.Response.fromStream(response);
    });

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
      var response = await _network(
        () => _http.get(_uri(path), headers: _headers),
      );
      if (response.statusCode == 401 &&
          _canRefresh(path) &&
          await _refreshOnce()) {
        response = await _network(
          () => _http.get(_uri(path), headers: _headers),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _parse(response);
        throw ApiException(response.statusCode, 'Download failed');
      }
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
      var response = await _network(send);

      if (response.statusCode == 401 &&
          _canRefresh(path) &&
          await _refreshOnce()) {
        response = await _network(send);
      }

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

  void dispose() => _http.close();
}
