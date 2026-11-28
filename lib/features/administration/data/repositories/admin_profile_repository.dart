import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/admin_profile_models.dart';

class AdminProfileRepository {
  const AdminProfileRepository(this.api);
  final ApiClient api;

  Future<AdminProfileDetails> profile() => _guarded(
    () async =>
        AdminProfileDetails.fromJson(await api.get('/api/admin/profile')),
  );

  Future<AdminProfileDetails> updateDisplayName(String displayName) {
    final normalized = displayName.trim();
    if (normalized.isEmpty ||
        normalized.length > 200 ||
        normalized.runes.any((character) => character < 32)) {
      throw ArgumentError(
        'Display name must contain 1 to 200 safe characters.',
      );
    }
    return _guarded(() async {
      final result = AdminProfileDetails.fromJson(
        await api.put('/api/admin/profile', <String, dynamic>{
          'displayName': normalized,
        }),
      );
      if (result.displayName != normalized) {
        throw const FormatException(
          'Profile update was not confirmed by the server.',
        );
      }
      return result;
    });
  }

  Future<AdminSecurityDetails> security() => _guarded(
    () async => AdminSecurityDetails.fromJson(
      await api.get('/api/admin/profile/security'),
    ),
  );

  Future<List<AdminSessionDetails>> sessions() => _guarded(() async {
    final raw = await api.get('/api/admin/profile/sessions');
    if (raw is! List) {
      throw const FormatException('Invalid administrator session directory.');
    }
    final items = raw.map(AdminSessionDetails.fromJson).toList(growable: false);
    if (items.map((item) => item.id.toLowerCase()).toSet().length !=
            items.length ||
        items.where((item) => item.isCurrent).length > 1) {
      throw const FormatException('Invalid administrator session collection.');
    }
    return List.unmodifiable(items);
  });

  Future<void> revokeSession(String sessionId) {
    _requireId(sessionId);
    return _guarded(() => api.delete('/api/admin/profile/sessions/$sessionId'));
  }

  Future<int> revokeOtherSessions() => _guarded(() async {
    final raw = await api.post(
      '/api/admin/profile/sessions/revoke-others',
      <String, dynamic>{},
    );
    if (raw is! Map || raw['revoked'] is! int || (raw['revoked'] as int) < 0) {
      throw const FormatException('Invalid session revocation response.');
    }
    return raw['revoked'] as int;
  });

  Future<List<AdminLoginHistoryEntry>> loginHistory({
    int page = 1,
    int pageSize = 20,
  }) {
    if (page < 1 || page > 1000000 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid login history page.');
    }
    return _guarded(() async {
      final path =
          Uri(
            path: '/api/admin/profile/login-history',
            queryParameters: {'page': '$page', 'pageSize': '$pageSize'},
          ).toString();
      final raw = await api.get(path);
      if (raw is! List || raw.length > pageSize) {
        throw const FormatException('Invalid login history response.');
      }
      return List.unmodifiable(raw.map(AdminLoginHistoryEntry.fromJson));
    });
  }

  Future<T> _guarded<T>(Future<T> Function() operation) async {
    final generation = authSession.generation;
    if (!authSession.authenticated) {
      throw const ApiException(401, 'Authentication is required.');
    }
    final result = await operation();
    if (!authSession.authenticated || generation != authSession.generation) {
      throw const ApiException(401, 'The administration session changed.');
    }
    return result;
  }

  void _requireId(String value) {
    if (!_uuid.hasMatch(value)) {
      throw ArgumentError('Invalid session identifier.');
    }
  }
}

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
