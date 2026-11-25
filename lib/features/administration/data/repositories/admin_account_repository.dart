import '../../../../core/network/api_client.dart';

enum AdminAccountStatus { all, enabled, disabled }

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isDisabled,
    required this.emailVerified,
    required this.mfaEnabled,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool isDisabled;
  final bool emailVerified;
  final bool mfaEnabled;

  factory AdminAccount.fromJson(dynamic raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        !AdminAccountRepository.validId(raw['id'] as String) ||
        raw['email'] is! String ||
        raw['displayName'] is! String ||
        raw['role'] is! String ||
        raw['isDisabled'] is! bool ||
        raw['emailVerified'] is! bool ||
        raw['mfaEnabled'] is! bool) {
      throw const FormatException('Invalid admin account response');
    }

    return AdminAccount(
      id: raw['id'] as String,
      email: raw['email'] as String,
      displayName: raw['displayName'] as String,
      role: raw['role'] as String,
      isDisabled: raw['isDisabled'] as bool,
      emailVerified: raw['emailVerified'] as bool,
      mfaEnabled: raw['mfaEnabled'] as bool,
    );
  }
}

class AdminAccountPage {
  const AdminAccountPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<AdminAccount> items;
  final int page;
  final int pageSize;
  final int total;
}

/// Adapter for the Administrator-policy account management contract.
/// The integration team must confirm the server authorization and MFA
/// policy before exposing these operations in the application.
class AdminAccountRepository {
  const AdminAccountRepository(this.api);

  final ApiClient api;

  static bool validId(String value) =>
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value) &&
      value != '00000000-0000-0000-0000-000000000000';

  Future<AdminAccountPage> getUsers({
    int page = 1,
    int pageSize = 20,
    String search = '',
    AdminAccountStatus status = AdminAccountStatus.all,
  }) async {
    if (page < 1 ||
        page > 1000000 ||
        pageSize < 1 ||
        pageSize > 100 ||
        search.length > 200) {
      throw ArgumentError('Invalid account search parameters');
    }

    final path =
        Uri(
          path: '/api/admin/users',
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            'status': status.name,
            if (search.trim().isNotEmpty) 'search': search.trim(),
          },
        ).toString();

    final raw = await api.get(path);

    if (raw is! Map ||
        raw['page'] != page ||
        raw['pageSize'] != pageSize ||
        raw['total'] is! int ||
        (raw['total'] as int) < 0 ||
        raw['items'] is! List) {
      throw const FormatException('Invalid account pagination');
    }

    final items = (raw['items'] as List).map(AdminAccount.fromJson).toList();

    final ids = items.map((item) => item.id.toLowerCase()).toSet();

    if (items.length > pageSize ||
        items.length > (raw['total'] as int) ||
        ids.length != items.length) {
      throw const FormatException('Invalid account list');
    }

    return AdminAccountPage(
      items: List.unmodifiable(items),
      page: page,
      pageSize: pageSize,
      total: raw['total'] as int,
    );
  }

  Future<AdminAccount> setStatus({
    required String userId,
    required String actorId,
    required bool disabled,
    String? reason,
  }) async {
    _validateTarget(userId, actorId);

    final normalized = reason?.trim();

    if (disabled &&
        (normalized == null || normalized.isEmpty || normalized.length > 500)) {
      throw ArgumentError('A valid disable reason is required');
    }

    final raw = await api.put('/api/admin/users/$userId/status', {
      'disabled': disabled,
      'reason': disabled ? normalized : null,
    });

    final account = _validateResponse(raw, userId);

    if (account.isDisabled != disabled) {
      throw const FormatException('Unexpected account status');
    }

    return account;
  }

  Future<AdminAccount> setRole({
    required String userId,
    required String actorId,
    required String role,
  }) async {
    _validateTarget(userId, actorId);

    final value = role.trim();

    if (value.isEmpty || value.length > 100) {
      throw ArgumentError('Invalid account role');
    }

    final raw = await api.put('/api/admin/users/$userId/role', {'role': value});

    final account = _validateResponse(raw, userId);

    if (account.role.toLowerCase() != value.toLowerCase()) {
      throw const FormatException('Unexpected account role');
    }

    return account;
  }

  static void _validateTarget(String userId, String actorId) {
    if (!validId(userId) || !validId(actorId)) {
      throw ArgumentError('Invalid account identity');
    }

    // Conservative UI-side restriction.
    // The server remains responsible for authorization.
    if (userId.toLowerCase() == actorId.toLowerCase()) {
      throw ArgumentError('Self-management is not allowed');
    }
  }

  static AdminAccount _validateResponse(dynamic raw, String userId) {
    final account = AdminAccount.fromJson(raw);

    if (account.id.toLowerCase() != userId.toLowerCase()) {
      throw const FormatException('Unexpected account identity');
    }

    return account;
  }
}
