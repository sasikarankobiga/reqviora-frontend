import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../../projects/application/projects_providers.dart';
import '../../../auth/application/auth_providers.dart';
import '../../data/repositories/admin_profile_repository.dart';
import '../../domain/admin_profile_models.dart';

class AdminProfileSessionsPage extends ConsumerStatefulWidget {
  const AdminProfileSessionsPage({super.key});
  @override
  ConsumerState<AdminProfileSessionsPage> createState() =>
      _AdminProfileSessionsPageState();
}

class _AdminProfileSessionsPageState
    extends ConsumerState<AdminProfileSessionsPage> {
  final _displayName = TextEditingController();
  late final AdminProfileRepository _repository;
  AdminProfileDetails? _profile;
  AdminSecurityDetails? _security;
  List<AdminSessionDetails> _sessions = const [];
  List<AdminLoginHistoryEntry> _history = const [];
  bool _dirty = false;
  bool _busy = false;
  String? _error;
  String? _notice;
  int _historyPage = 1;
  int _operation = 0;
  int _generation = authSession.generation;

  @override
  void initState() {
    super.initState();
    _repository = AdminProfileRepository(ref.read(apiClientProvider));
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_generation == authSession.generation) return;
    _generation = authSession.generation;
    _operation++;
    if (mounted) {
      setState(() {
        _clear();
        _busy = false;
      });
    }
  }

  void _clear() {
    _profile = null;
    _security = null;
    _sessions = const [];
    _history = const [];
    _displayName.clear();
    _dirty = false;
    _error = null;
    _notice = null;
    _historyPage = 1;
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _displayName.dispose();
    super.dispose();
  }

  String _t(String en, String ta) => uiText(context, en, ta);
  String _date(DateTime value) => value.toLocal().toString();
  bool _current(int operation, int generation) =>
      mounted &&
      operation == _operation &&
      generation == authSession.generation &&
      authSession.authenticated;

  Future<void> _load({int historyPage = 1}) async {
    if (_busy || !authSession.authenticated || isLocalDemo) return;
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final values = await Future.wait<Object>([
        _repository.profile(),
        _repository.security(),
        _repository.sessions(),
        _repository.loginHistory(page: historyPage),
      ]);
      if (!_current(operation, generation)) return;
      final profile = values[0] as AdminProfileDetails;
      setState(() {
        _profile = profile;
        _security = values[1] as AdminSecurityDetails;
        _sessions = values[2] as List<AdminSessionDetails>;
        _history = values[3] as List<AdminLoginHistoryEntry>;
        _displayName.text = profile.displayName;
        _dirty = false;
        _historyPage = historyPage;
      });
    } on ApiException catch (error) {
      if (_current(operation, generation)) {
        setState(() => _error = _apiError(error));
      }
    } on FormatException {
      if (_current(operation, generation)) {
        setState(
          () =>
              _error = _t(
                'The server returned incompatible profile data.',
                'பின்தளம் பொருந்தாத சுயவிவரத் தரவை வழங்கியது.',
              ),
        );
      }
    } finally {
      if (_current(operation, generation)) setState(() => _busy = false);
    }
  }

  String _apiError(ApiException error) => switch (error.statusCode) {
    401 => _t(
      'Authentication or administrator MFA is required.',
      'உள்நுழைவும் நிர்வாகி MFA-வும் தேவை.',
    ),
    403 => _t(
      'Administrator access is not authorized.',
      'நிர்வாகி அணுகல் அனுமதிக்கப்படவில்லை.',
    ),
    404 => _t(
      'Profile or session was not found.',
      'சுயவிவரம் அல்லது அமர்வு கிடைக்கவில்லை.',
    ),
    _ => _t(
      'Unable to complete the profile request.',
      'சுயவிவரக் கோரிக்கையை முடிக்க முடியவில்லை.',
    ),
  };

  Future<void> _saveProfile() async {
    if (_busy || !_dirty) return;
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final profile = await _repository.updateDisplayName(_displayName.text);
      if (!_current(operation, generation)) return;
      setState(() {
        _profile = profile;
        _displayName.text = profile.displayName;
        _dirty = false;
        _notice = _t('Profile updated.', 'சுயவிவரம் புதுப்பிக்கப்பட்டது.');
      });
      ref.invalidate(authenticatedProfileProvider);
    } on ArgumentError {
      if (_current(operation, generation)) {
        setState(
          () =>
              _error = _t(
                'Enter a display name from 1 to 200 characters.',
                '1 முதல் 200 எழுத்துகள் கொண்ட காட்சிப் பெயரை உள்ளிடவும்.',
              ),
        );
      }
    } on ApiException catch (error) {
      if (_current(operation, generation)) {
        setState(() => _error = _apiError(error));
      }
    } finally {
      if (_current(operation, generation)) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(AdminSessionDetails session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              session.isCurrent
                  ? _t(
                    'Revoke current session?',
                    'தற்போதைய அமர்வை ரத்து செய்யவா?',
                  )
                  : _t('Revoke session?', 'அமர்வை ரத்து செய்யவா?'),
            ),
            content: Text(
              session.isCurrent
                  ? _t(
                    'You will be signed out after server confirmation.',
                    'பின்தள உறுதிப்படுத்தலுக்குப் பிறகு வெளியேற்றப்படுவீர்கள்.',
                  )
                  : session.id,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_t('Confirm', 'உறுதிப்படுத்து')),
              ),
            ],
          ),
    );
    if (confirmed != true || _busy) return;
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.revokeSession(session.id);
      if (!_current(operation, generation)) return;
      if (session.isCurrent) {
        authSession.signOut();
        return;
      }
      setState(() => _busy = false);
      await _load(historyPage: _historyPage);
    } on ApiException catch (error) {
      if (_current(operation, generation)) {
        setState(() => _error = _apiError(error));
      }
    } finally {
      if (_current(operation, generation)) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              _t(
                'Revoke all other sessions?',
                'மற்ற அனைத்து அமர்வுகளையும் ரத்து செய்யவா?',
              ),
            ),
            content: Text(
              _t(
                'The current session will remain active.',
                'தற்போதைய அமர்வு தொடர்ந்து செயல்படும்.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_t('Confirm', 'உறுதிப்படுத்து')),
              ),
            ],
          ),
    );
    if (confirmed != true || _busy) return;
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = await _repository.revokeOtherSessions();
      if (!_current(operation, generation)) return;
      setState(() {
        _busy = false;
        _notice =
            '${_t('Sessions revoked', 'ரத்து செய்யப்பட்ட அமர்வுகள்')}: $count';
      });
      await _load(historyPage: _historyPage);
    } on ApiException catch (error) {
      if (_current(operation, generation)) {
        setState(() => _error = _apiError(error));
      }
    } finally {
      if (_current(operation, generation)) setState(() => _busy = false);
    }
  }

  String _maskedIp(String value) {
    final parts = value.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.*.*';
    final colon = value.indexOf(':');
    return colon > 0
        ? '${value.substring(0, colon)}:*'
        : _t('Protected', 'பாதுகாக்கப்பட்டது');
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(
                  _t(
                    'Discard unsaved profile changes?',
                    'சேமிக்காத சுயவிவர மாற்றங்களை கைவிடவா?',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(_t('Cancel', 'ரத்து செய்')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(_t('Discard', 'கைவிடு')),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t('Administrator profile', 'நிர்வாகி சுயவிவரம்')),
        ),
        body: Center(
          child: Text(
            _t(
              'Authenticated administrator access is required.',
              'உள்நுழைந்த நிர்வாகி அணுகல் தேவை.',
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (!context.mounted || !discard) return;
        setState(() => _dirty = false);
        context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _t(
              'Administrator profile and sessions',
              'நிர்வாகி சுயவிவரமும் அமர்வுகளும்',
            ),
          ),
          actions: [
            IconButton(
              onPressed: _busy ? null : () => _load(historyPage: _historyPage),
              tooltip: _t('Refresh', 'புதுப்பி'),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_profile == null && !_busy)
              FilledButton(
                key: const ValueKey('admin-profile-load'),
                onPressed: () => _load(),
                child: Text(_t('Load profile', 'சுயவிவரத்தை ஏற்று')),
              ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_notice != null)
              Semantics(liveRegion: true, child: Text(_notice!)),
            if (_profile case final profile?) ...[
              Text(
                _t('Profile', 'சுயவிவரம்'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SelectableText(
                '${_t('Administrator ID', 'நிர்வாகி அடையாளம்')}: ${profile.id}',
              ),
              SelectableText('${_t('Email', 'மின்னஞ்சல்')}: ${profile.email}'),
              Text(
                '${_t('Email verified', 'மின்னஞ்சல் உறுதி')}: ${profile.emailVerified}',
              ),
              Text(
                '${_t('MFA enabled', 'MFA இயக்கம்')}: ${profile.mfaEnabled}',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('admin-profile-name'),
                controller: _displayName,
                enabled: !_busy,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: _t('Display name', 'காட்சிப் பெயர்'),
                ),
                onChanged:
                    (value) => setState(
                      () => _dirty = value.trim() != profile.displayName,
                    ),
              ),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    key: const ValueKey('admin-profile-save'),
                    onPressed: _busy || !_dirty ? null : _saveProfile,
                    child: Text(_t('Save', 'சேமி')),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy || !_dirty
                            ? null
                            : () => setState(() {
                              _displayName.text = profile.displayName;
                              _dirty = false;
                            }),
                    child: Text(_t('Discard changes', 'மாற்றங்களை கைவிடு')),
                  ),
                ],
              ),
              const Divider(height: 32),
              _securitySection(),
              _sessionSection(),
              _historySection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _securitySection() {
    final security = _security;
    if (security == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Account security', 'கணக்கு பாதுகாப்பு'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${_t('Active sessions', 'செயலில் உள்ள அமர்வுகள்')}: ${security.activeSessions}',
        ),
        Text(
          '${_t('Recent security events', 'சமீபத்திய பாதுகாப்பு நிகழ்வுகள்')}: ${security.recentEvents.length}',
        ),
        TextButton(
          onPressed: () => context.go('/security/mfa'),
          child: Text(
            _t('Open MFA security settings', 'MFA பாதுகாப்பு அமைப்புகளைத் திற'),
          ),
        ),
      ],
    );
  }

  Widget _sessionSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 32),
      Text(
        _t('Active sessions', 'செயலில் உள்ள அமர்வுகள்'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (_sessions.isEmpty)
        Text(
          _t('No active sessions reported.', 'செயலில் உள்ள அமர்வுகள் இல்லை.'),
        ),
      for (final session in _sessions)
        Card(
          child: ListTile(
            title: Text(
              session.isCurrent
                  ? _t('Current session', 'தற்போதைய அமர்வு')
                  : _t('Active session', 'செயலில் உள்ள அமர்வு'),
            ),
            subtitle: Text(
              '${session.id}\n${_t('Created', 'உருவாக்கப்பட்டது')}: ${_date(session.createdAt)}\n${_t('Expires', 'காலாவதி')}: ${_date(session.expiresAt)}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              key: ValueKey('revoke-session-${session.id}'),
              onPressed: _busy ? null : () => _revoke(session),
              tooltip: _t('Revoke', 'ரத்து செய்'),
              icon: const Icon(Icons.logout),
            ),
          ),
        ),
      FilledButton.tonal(
        key: const ValueKey('revoke-other-sessions'),
        onPressed: _busy ? null : _revokeOthers,
        child: Text(_t('Revoke other sessions', 'மற்ற அமர்வுகளை ரத்து செய்')),
      ),
    ],
  );

  Widget _historySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 32),
      Text(
        _t('Login history', 'உள்நுழைவு வரலாறு'),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (_history.isEmpty)
        Text(
          _t(
            'No login history on this page.',
            'இந்தப் பக்கத்தில் உள்நுழைவு வரலாறு இல்லை.',
          ),
        ),
      for (final item in _history)
        ListTile(
          title: Text(
            item.succeeded
                ? _t('Successful login', 'வெற்றிகரமான உள்நுழைவு')
                : _t('Failed login', 'தோல்வியுற்ற உள்நுழைவு'),
          ),
          subtitle: Text(
            '${_t('Device', 'சாதனம்')}: ${item.deviceId}\n${_t('IP', 'IP')}: ${_maskedIp(item.ipAddress)}\n${_date(item.occurredAt)}',
          ),
          trailing: item.otpRequired ? const Icon(Icons.verified_user) : null,
        ),
      Wrap(
        spacing: 12,
        children: [
          OutlinedButton(
            onPressed:
                _busy || _historyPage <= 1
                    ? null
                    : () => _load(historyPage: _historyPage - 1),
            child: Text(_t('Previous', 'முந்தையது')),
          ),
          Text('${_t('Page', 'பக்கம்')} $_historyPage'),
          OutlinedButton(
            onPressed:
                _busy || _history.length < 20
                    ? null
                    : () => _load(historyPage: _historyPage + 1),
            child: Text(_t('Next', 'அடுத்தது')),
          ),
        ],
      ),
    ],
  );
}
