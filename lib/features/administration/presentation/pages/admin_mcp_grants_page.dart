import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/admin_mcp_grant_repository.dart';
import '../../domain/admin_mcp_grant.dart';

class AdminMcpGrantsPage extends ConsumerStatefulWidget {
  const AdminMcpGrantsPage({super.key});

  @override
  ConsumerState<AdminMcpGrantsPage> createState() => _AdminMcpGrantsPageState();
}

class _AdminMcpGrantsPageState extends ConsumerState<AdminMcpGrantsPage> {
  final _search = TextEditingController();
  final _project = TextEditingController();
  AdminMcpGrantState _state = AdminMcpGrantState.all;
  AdminMcpGrantPage? _data;
  bool _busy = false;
  String? _error;
  int _operation = 0;
  int _session = authSession.generation;
  late final AdminMcpGrantRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = AdminMcpGrantRepository(ref.read(apiClientProvider));
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_session == authSession.generation) return;
    _session = authSession.generation;
    _operation++;
    if (mounted) {
      setState(() {
        _data = null;
        _busy = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _search.dispose();
    _project.dispose();
    super.dispose();
  }

  Future<void> _load([int page = 1]) async {
    if (_busy || !authSession.authenticated || isLocalDemo) return;
    final project = _project.text.trim();
    final operation = ++_operation;
    final session = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _repository.list(
        page: page,
        search: _search.text,
        state: _state,
        projectId: project.isEmpty ? null : project,
      );
      if (!_current(operation, session)) return;
      setState(() => _data = data);
    } on ApiException catch (error) {
      if (_current(operation, session)) {
        setState(() => _error = _apiError(error));
      }
    } on FormatException {
      if (_current(operation, session)) {
        setState(
          () =>
              _error = _t(
                'The server returned incompatible grant data.',
                'பின்தளம் பொருந்தாத அனுமதித் தரவை வழங்கியது.',
              ),
        );
      }
    } on ArgumentError {
      if (_current(operation, session)) {
        setState(
          () =>
              _error = _t(
                'Check the project ID and filters.',
                'திட்ட அடையாளத்தையும் வடிகட்டிகளையும் சரிபார்க்கவும்.',
              ),
        );
      }
    } finally {
      if (_current(operation, session)) setState(() => _busy = false);
    }
  }

  bool _current(int operation, int session) =>
      mounted &&
      operation == _operation &&
      session == authSession.generation &&
      authSession.authenticated;

  String _apiError(ApiException error) => switch (error.statusCode) {
    401 => _t(
      'Authentication or administrator MFA is required.',
      'உள்நுழைவும் நிர்வாகி MFA-வும் தேவை.',
    ),
    403 => _t(
      'Administrator access is not authorized.',
      'நிர்வாகி அணுகல் அனுமதிக்கப்படவில்லை.',
    ),
    404 => _t('Grant was not found.', 'அனுமதி கிடைக்கவில்லை.'),
    429 => _t(
      'Too many requests. Try again later.',
      'அதிக கோரிக்கைகள். பின்னர் முயலவும்.',
    ),
    _ => _t('Unable to load MCP grants.', 'MCP அனுமதிகளை ஏற்ற முடியவில்லை.'),
  };

  String _t(String en, String ta) => uiText(context, en, ta);
  String _date(DateTime? value) =>
      value?.toLocal().toString() ?? _t('Not available', 'கிடைக்கவில்லை');

  Future<void> _details(AdminMcpGrant item) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final details = await _repository.details(item.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(_t('MCP grant details', 'MCP அனுமதி விவரங்கள்')),
              content: SingleChildScrollView(child: _metadata(details)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t('Close', 'மூடு')),
                ),
              ],
            ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } on FormatException {
      if (mounted) {
        setState(
          () =>
              _error = _t(
                'The server returned incompatible grant data.',
                'பின்தளம் பொருந்தாத அனுமதித் தரவை வழங்கியது.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(AdminMcpGrant item) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(_t('Emergency grant revocation', 'அவசர அனுமதி ரத்து')),
            content: TextField(
              key: const ValueKey('mcp-revoke-reason'),
              controller: reason,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _t('Required reason', 'தேவையான காரணம்'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                key: const ValueKey('mcp-confirm-revoke'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_t('Revoke', 'ரத்து செய்')),
              ),
            ],
          ),
    );
    final value = reason.text;
    reason.dispose();
    if (confirmed != true) return;
    if (value.trim().length < 3) {
      setState(
        () =>
            _error = _t(
              'Enter a reason of at least 3 characters.',
              'குறைந்தது 3 எழுத்துகள் கொண்ட காரணத்தை உள்ளிடவும்.',
            ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.revoke(item.id, value);
      if (mounted) {
        setState(() => _busy = false);
        await _load(_data?.page ?? 1);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _apiError(error));
    } on StateError {
      if (mounted) {
        setState(
          () =>
              _error = _t(
                'Revocation is already in progress.',
                'ரத்து செய்யும் கோரிக்கை ஏற்கனவே நடைபெறுகிறது.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _metadata(AdminMcpGrant item) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(_t('Grant ID', 'அனுமதி அடையாளம்'), item.id),
      _line(_t('Project ID', 'திட்ட அடையாளம்'), item.projectId),
      _line(
        _t('Approved revision', 'அங்கீகரிக்கப்பட்ட பதிப்பு'),
        item.approvedRevisionId,
      ),
      _line(_t('Owner ID', 'உரிமையாளர் அடையாளம்'), item.ownerId),
      _line(_t('Status', 'நிலை'), item.state.name),
      _line(_t('Created', 'உருவாக்கப்பட்டது'), _date(item.createdAt)),
      _line(_t('Expires', 'காலாவதி'), _date(item.expiresAt)),
      if (item.revokedAt != null)
        _line(_t('Revoked', 'ரத்து செய்யப்பட்டது'), _date(item.revokedAt)),
      if (item.revokedBy != null)
        _line(_t('Revoked by', 'ரத்து செய்தவர்'), item.revokedBy!),
      if (item.revocationReason != null)
        _line(_t('Reason', 'காரணம்'), item.revocationReason!),
    ],
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SelectableText('$label: $value'),
  );

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) return _blocked();
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('MCP grant administration', 'MCP அனுமதி நிர்வாகம்')),
        actions: [
          IconButton(
            tooltip: _t('Export diagnostics', 'ஏற்றுமதி கண்டறிதல்'),
            onPressed: () => context.go('/admin/export-diagnostics'),
            icon: const Icon(Icons.analytics_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _t(
              'Backend-authorized grant metadata only. Credentials and Blueprint contents are never displayed.',
              'பின்தளம் அனுமதித்த தகவல்கள் மட்டும். சான்றுகளும் Blueprint உள்ளடக்கமும் காட்டப்படாது.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  key: const ValueKey('mcp-admin-search'),
                  controller: _search,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: _t('Search IDs', 'அடையாளங்களைத் தேடு'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                width: 340,
                child: TextField(
                  key: const ValueKey('mcp-project-filter'),
                  controller: _project,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Project ID (optional)',
                      'திட்ட அடையாளம் (விருப்பம்)',
                    ),
                  ),
                ),
              ),
              DropdownButton<AdminMcpGrantState>(
                value: _state,
                onChanged:
                    _busy ? null : (value) => setState(() => _state = value!),
                items:
                    AdminMcpGrantState.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
              ),
              FilledButton.icon(
                key: const ValueKey('mcp-admin-load'),
                onPressed: _busy ? null : () => _load(),
                icon: const Icon(Icons.refresh),
                label: Text(_t('Refresh', 'புதுப்பி')),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (!_busy && data != null) ...[
            Text('${_t('Total', 'மொத்தம்')}: ${data.total}'),
            if (data.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _t('No matching grants.', 'பொருந்தும் அனுமதிகள் இல்லை.'),
                ),
              ),
            for (final item in data.items)
              Card(
                child: ListTile(
                  title: Text(
                    '${item.state.name.toUpperCase()} · ${item.projectId}',
                  ),
                  subtitle: Text(
                    '${_t('Grant', 'அனுமதி')}: ${item.id}\n${_t('Expires', 'காலாவதி')}: ${_date(item.expiresAt)}',
                  ),
                  isThreeLine: true,
                  onTap: () => _details(item),
                  trailing:
                      item.state == AdminMcpGrantState.revoked
                          ? null
                          : IconButton(
                            key: ValueKey('revoke-${item.id}'),
                            tooltip: _t(
                              'Emergency revoke',
                              'அவசரமாக ரத்து செய்',
                            ),
                            onPressed: _busy ? null : () => _revoke(item),
                            icon: const Icon(Icons.block),
                          ),
                ),
              ),
            _pager(data.page, data.pageSize, data.total),
          ],
        ],
      ),
    );
  }

  Widget _pager(int page, int size, int total) => Wrap(
    spacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton(
        onPressed: _busy || page <= 1 ? null : () => _load(page - 1),
        child: Text(_t('Previous', 'முந்தையது')),
      ),
      Text('${_t('Page', 'பக்கம்')} $page'),
      OutlinedButton(
        onPressed: _busy || page * size >= total ? null : () => _load(page + 1),
        child: Text(_t('Next', 'அடுத்தது')),
      ),
    ],
  );

  Widget _blocked() => Scaffold(
    appBar: AppBar(
      title: Text(_t('MCP grant administration', 'MCP அனுமதி நிர்வாகம்')),
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
