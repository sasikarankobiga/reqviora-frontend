import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../domain/mcp_access_grant.dart';

/// Standalone grant lifecycle UI.
///
/// The integration layer must supply server-verified
/// revisions, grants, permissions and expiry options.
/// No API endpoint or credential is invented here.
class McpGrantManagementPanel extends StatefulWidget {
  const McpGrantManagementPanel({
    super.key,
    required this.projectId,
    this.revisions = const [],
    this.grants = const [],
    this.expiryOptions = const [],
    this.integrationEnabled = false,
    this.canManage = false,
    this.onCreate,
    this.onRevoke,
  });

  final String projectId;
  final List<McpApprovedRevision> revisions;
  final List<McpAccessGrant> grants;
  final List<Duration> expiryOptions;

  final bool integrationEnabled;
  final bool canManage;

  final Future<McpGrantCredential> Function(McpGrantCreationIntent intent)?
  onCreate;

  final Future<void> Function(String grantId)? onRevoke;

  @override
  State<McpGrantManagementPanel> createState() =>
      _McpGrantManagementPanelState();
}

class _McpGrantManagementPanelState extends State<McpGrantManagementPanel> {
  String? _revisionId;
  Duration? _expiry;

  bool _busy = false;
  bool _confirming = false;
  bool _refreshRequired = false;

  String? _error;
  String? _notice;
  String? _credential;

  int _generation = authSession.generation;
  int _operation = 0;

  bool get _allowed =>
      widget.integrationEnabled &&
      widget.canManage &&
      authSession.authenticated &&
      !isLocalDemo &&
      McpGrantValidation.validId(widget.projectId);

  bool get _ready =>
      _allowed && !_busy && !_refreshRequired && _credential == null;

  List<McpApprovedRevision> get _revisions {
    final values = <String, McpApprovedRevision>{};

    for (final item in widget.revisions) {
      if (McpGrantValidation.sameId(item.projectId, widget.projectId)) {
        values.putIfAbsent(item.revisionId.toLowerCase(), () => item);
      }
    }

    return values.values.toList();
  }

  List<McpAccessGrant> get _grants {
    final values = <String, McpAccessGrant>{};

    for (final item in widget.grants) {
      if (item.belongsTo(widget.projectId)) {
        values.putIfAbsent(item.id.toLowerCase(), () => item);
      }
    }

    return values.values.toList();
  }

  List<Duration> get _expiryOptions =>
      widget.expiryOptions
          .where((value) => value.inSeconds > 0)
          .toSet()
          .toList();

  McpApprovedRevision? get _selectedRevision {
    for (final item in _revisions) {
      if (item.revisionId == _revisionId) {
        return item;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _clear() {
    _operation++;
    _revisionId = null;
    _expiry = null;
    _confirming = false;
    _refreshRequired = true;
    _credential = null;
    _error = null;
    _notice = null;
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;
    setState(_clear);
  }

  @override
  void didUpdateWidget(covariant McpGrantManagementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId ||
        oldWidget.canManage != widget.canManage ||
        oldWidget.integrationEnabled != widget.integrationEnabled) {
      _clear();
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _credential = null;
    super.dispose();
  }

  bool _active(int operation) =>
      mounted &&
      _allowed &&
      _generation == authSession.generation &&
      operation == _operation;

  String _errorMessage(Object failure) {
    if (failure is ApiException) {
      switch (failure.statusCode) {
        case 401:
          return 'Session expired. Sign in again.';
        case 403:
          return 'Permission denied.';
        case 404:
          return 'Grant service or revision is unavailable.';
        case 409:
          return 'Grant state changed. Reload before retrying.';
        case 429:
          return 'Too many requests. Try again later.';
      }
    }

    return 'Operation could not be confirmed. Reload grants.';
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    setState(() => _confirming = true);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                key: const ValueKey('mcp-grant-cancel'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(uiText(dialogContext, 'Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                key: const ValueKey('mcp-grant-confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(uiText(dialogContext, 'Confirm', 'உறுதிப்படுத்து')),
              ),
            ],
          ),
    );

    if (mounted) {
      setState(() => _confirming = false);
    }

    return result == true;
  }

  Future<void> _create() async {
    final revision = _selectedRevision;
    final expiry = _expiry;
    final callback = widget.onCreate;

    if (!_ready ||
        revision == null ||
        expiry == null ||
        !_expiryOptions.contains(expiry) ||
        callback == null) {
      return;
    }

    final operation = ++_operation;
    final project = widget.projectId;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final accepted = await _confirm(
        title: uiText(
          context,
          'Create access grant?',
          'அணுகல் அனுமதியை உருவாக்கவா?',
        ),
        message:
            'Create read-only access to approved '
            'revision v${revision.draftVersion}?\n\n'
            'The issued credential must be kept private.',
      );

      if (!accepted || !_active(operation)) return;

      if (!_revisions.any(
            (item) =>
                item.revisionId == revision.revisionId &&
                item.draftVersion == revision.draftVersion,
          ) ||
          !_expiryOptions.contains(expiry) ||
          callback != widget.onCreate) {
        throw StateError('Grant configuration changed');
      }

      final now = DateTime.now().toUtc();

      final intent = McpGrantCreationIntent(
        projectId: project,
        revision: revision,
        expiresAt: now.add(expiry),
        now: now,
        confirmed: true,
      );

      final result = await callback(intent);

      if (!_active(operation)) {
        result.clear();
        return;
      }

      final secret = result.take();

      if (secret == null) {
        throw const FormatException('Missing issued credential');
      }

      setState(() {
        _credential = secret;
        _refreshRequired = true;
        _notice =
            'Grant creation confirmed. '
            'Reload grants after saving the credential.';
      });
    } catch (failure) {
      if (!_active(operation)) return;

      setState(() {
        _error = _errorMessage(failure);
        _refreshRequired = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  Future<void> _revoke(McpAccessGrant grant) async {
    final callback = widget.onRevoke;

    if (!_ready ||
        callback == null ||
        !grant.belongsTo(widget.projectId) ||
        !grant.canRequestRevocationAt(DateTime.now())) {
      return;
    }

    final operation = ++_operation;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      final accepted = await _confirm(
        title: uiText(
          context,
          'Revoke access grant?',
          'அணுகல் அனுமதியை ரத்து செய்யவா?',
        ),
        message:
            'This will withdraw access associated '
            'with this grant. Continue?',
      );

      if (!accepted || !_active(operation)) return;

      final stillActive = _grants.any(
        (item) =>
            McpGrantValidation.sameId(item.id, grant.id) &&
            item.canRequestRevocationAt(DateTime.now()),
      );

      if (!stillActive || callback != widget.onRevoke) {
        throw StateError('Grant state changed');
      }

      await callback(grant.id);

      if (!_active(operation)) return;

      setState(() {
        _notice = 'Grant revocation confirmed. Reload grants.';
        _refreshRequired = true;
      });
    } catch (failure) {
      if (!_active(operation)) return;

      setState(() {
        _error = _errorMessage(failure);
        _refreshRequired = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  String _statusLabel(McpGrantStatus status) {
    return switch (status) {
      McpGrantStatus.active => uiText(context, 'Active', 'செயலில் உள்ளது'),
      McpGrantStatus.expired => uiText(context, 'Expired', 'காலாவதியானது'),
      McpGrantStatus.revoked => uiText(
        context,
        'Revoked',
        'ரத்து செய்யப்பட்டது',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final revisions = _revisions;
    final options = _expiryOptions;
    final grants = _grants;
    final now = DateTime.now().toUtc();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          uiText(context, 'MCP Access Management', 'MCP அணுகல் மேலாண்மை'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),

        if (!widget.integrationEnabled)
          const Text('MCP grant management awaits backend integration.')
        else if (!_allowed)
          const Text('Authorized project access is required.')
        else if (_refreshRequired)
          const Text('Reload verified grant data before another operation.'),

        if (_allowed && !_refreshRequired) ...[
          if (revisions.isEmpty) const Text('No approved revisions available.'),

          DropdownButtonFormField<String>(
            key: ValueKey('mcp-revision-${_selectedRevision?.revisionId}'),
            initialValue: _selectedRevision?.revisionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: uiText(
                context,
                'Approved revision',
                'அங்கீகரிக்கப்பட்ட பதிப்பு',
              ),
            ),
            items: [
              for (final item in revisions)
                DropdownMenuItem(
                  value: item.revisionId,
                  child: Text('Approved revision v${item.draftVersion}'),
                ),
            ],
            onChanged:
                _ready ? (value) => setState(() => _revisionId = value) : null,
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<Duration>(
            key: ValueKey(
              'mcp-expiry-${options.contains(_expiry) ? _expiry : null}',
            ),
            initialValue: options.contains(_expiry) ? _expiry : null,
            decoration: InputDecoration(
              labelText: uiText(
                context,
                'Access validity',
                'அணுகல் செல்லுபடியாகும் காலம்',
              ),
            ),
            items: [
              for (final duration in options)
                DropdownMenuItem(
                  value: duration,
                  child: Text('${duration.inSeconds} seconds'),
                ),
            ],
            onChanged:
                _ready ? (value) => setState(() => _expiry = value) : null,
          ),

          const SizedBox(height: 12),

          FilledButton.icon(
            key: const ValueKey('mcp-create-grant'),
            onPressed:
                _ready &&
                        _selectedRevision != null &&
                        options.contains(_expiry) &&
                        widget.onCreate != null
                    ? _create
                    : null,
            icon: const Icon(Icons.key_outlined),
            label: Text(
              uiText(
                context,
                'Create access grant',
                'அணுகல் அனுமதியை உருவாக்கு',
              ),
            ),
          ),

          const Divider(height: 32),

          Text(
            uiText(
              context,
              'Existing access grants',
              'தற்போதைய அணுகல் அனுமதிகள்',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),

          if (grants.isEmpty) const Text('No access grants available.'),

          for (final grant in grants)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grant: ${grant.id}'),
                    Text('Revision: ${grant.revisionId}'),
                    Text('Status: ${_statusLabel(grant.statusAt(now))}'),
                    Text('Expires: ${grant.expiresAt.toIso8601String()}'),
                    OutlinedButton(
                      key: ValueKey('mcp-revoke-${grant.id}'),
                      onPressed:
                          _ready &&
                                  widget.onRevoke != null &&
                                  grant.canRequestRevocationAt(now)
                              ? () => _revoke(grant)
                              : null,
                      child: Text(uiText(context, 'Revoke', 'ரத்து செய்')),
                    ),
                  ],
                ),
              ),
            ),
        ],

        if (_busy && !_confirming) const LinearProgressIndicator(),

        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),

        if (_notice != null) Semantics(liveRegion: true, child: Text(_notice!)),

        if (_allowed && _credential != null) ...[
          const SizedBox(height: 12),
          const Text(
            'One-time access credential. '
            'Save it securely. Do not share it publicly.',
          ),
          SelectableText(
            _credential!,
            key: const ValueKey('mcp-issued-credential'),
          ),
          TextButton(
            key: const ValueKey('mcp-dismiss-credential'),
            onPressed: () => setState(() => _credential = null),
            child: Text(uiText(context, 'Dismiss credential', 'மறை')),
          ),
        ],
      ],
    );
  }
}
