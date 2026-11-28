import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/language_settings.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});
  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  final _code = TextEditingController();
  final _search = TextEditingController();
  final _status = TextEditingController();
  AdminSection _section = AdminSection.overview;
  bool _authorized = false;
  bool _busy = false;
  String? _error;
  dynamic _result;
  int _page = 1;
  int _generation = 0;
  late int _sessionGeneration;

  @override
  void initState() {
    super.initState();
    _sessionGeneration = authSession.generation;
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_sessionGeneration == authSession.generation) return;
    _sessionGeneration = authSession.generation;
    _generation++;
    if (!mounted) return;
    setState(() {
      _authorized = false;
      _busy = false;
      _result = null;
      _error = null;
      _section = AdminSection.overview;
      _page = 1;
      _code.clear();
      _search.clear();
      _status.clear();
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _code.dispose();
    _search.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (_busy || isLocalDemo || !authSession.authenticated) return;
    final code = _code.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter a fresh six-digit authenticator code.');
      return;
    }
    final status = int.tryParse(_status.text.trim());
    if (_section == AdminSection.audit &&
        _status.text.trim().isNotEmpty &&
        (status == null || status < 100 || status > 599)) {
      setState(() => _error = 'Enter an HTTP status between 100 and 599.');
      return;
    }
    final generation = ++_generation;
    final section = _section;
    final search = _search.text;
    _code.clear();
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final data = await AdminRepository(
        ref.read(apiClientProvider),
      ).read(section, code, page: page, search: search, statusCode: status);
      if (!mounted || generation != _generation) return;
      final valid =
          section.paged
              ? data is Map && data['items'] is List && data['total'] is num
              : section == AdminSection.roles
              ? data is List
              : data is Map;
      if (!valid) throw const FormatException('Unexpected admin response.');
      setState(() {
        _authorized = true;
        _result = data;
        _page = page;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final status = error is ApiException ? error.statusCode : null;
      setState(() {
        if (status == 401 || status == 403) {
          _authorized = false;
          _section = AdminSection.overview;
          _page = 1;
          _search.clear();
          _status.clear();
        }
        _error = switch (status) {
          401 =>
            'Authentication or MFA verification failed. Use a fresh code or sign in again.',
          403 => 'Your account is not authorized for administration.',
          429 => 'Too many requests. Try again later.',
          404 => 'This API is unavailable on the connected backend.',
          _ => 'Unable to load administration data. Please try again.',
        };
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _select(AdminSection section) {
    if (_busy || !_authorized) return;
    setState(() {
      _section = section;
      _result = null;
      _error = null;
      _page = 1;
      _code.clear();
      _search.clear();
      _status.clear();
    });
  }

  String _label(String field) => field.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => ' ${match[0]!.toLowerCase()}',
  );
  String _value(dynamic value) =>
      value is String || value is num || value is bool
          ? '$value'
          : 'Not supplied';

  Widget _record(Map<dynamic, dynamic> record, List<String> fields) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final field in fields)
            if (record.containsKey(field))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SelectableText(
                  '${_label(field)}: ${_value(record[field])}',
                ),
              ),
        ],
      ),
    ),
  );

  Widget _data() {
    final data = _result;
    if (data == null) {
      return const Text('Enter a fresh MFA code and load data.');
    }
    final items =
        data is List
            ? data
            : data is Map
            ? data['items']
            : null;
    if (items is List) {
      final total =
          data is Map && data['total'] is num ? data['total'] as num : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total != null) Text('Total records: $total'),
          if (items.isEmpty) const Text('No matching records.'),
          for (final item in items)
            if (item is Map) _record(item, _section.fields),
          if (_section.paged)
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _page == 1 ? null : () => _load(_page - 1),
                  child: const Text('Previous'),
                ),
                Text('Page $_page'),
                OutlinedButton(
                  onPressed:
                      total == null || _page * 20 >= total
                          ? null
                          : () => _load(_page + 1),
                  child: const Text('Next'),
                ),
              ],
            ),
        ],
      );
    }
    if (data is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _record(data, _section.fields),
          if (_section == AdminSection.health && data['checks'] is List)
            for (final check in data['checks'] as List)
              if (check is Map) _record(check, ['name', 'status']),
        ],
      );
    }
    return const Text('Unexpected response.');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminTitle),
        actions: [
          IconButton(
            tooltip: uiText(context, 'MCP grants', 'MCP அனுமதிகள்'),
            onPressed: () => context.go('/admin/mcp-grants'),
            icon: const Icon(Icons.key_outlined),
          ),
          IconButton(
            tooltip: uiText(
              context,
              'Export diagnostics',
              'ஏற்றுமதி கண்டறிதல்',
            ),
            onPressed: () => context.go('/admin/export-diagnostics'),
            icon: const Icon(Icons.analytics_outlined),
          ),
          TextButton(
            onPressed: () => context.go('/projects'),
            child: Text(l10n.workspace),
          ),
        ],
      ),
      body: SafeArea(
        child:
            isLocalDemo || !authSession.authenticated
                ? Center(child: Text(l10n.adminRequiresAuthentication))
                : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          _authorized ? _section.label : l10n.verifyAdminAccess,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(l10n.adminMetadataDescription),
                        const SizedBox(height: 16),
                        if (_authorized)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final section in AdminSection.values)
                                ChoiceChip(
                                  label: Text(section.label),
                                  selected: section == _section,
                                  onSelected:
                                      _busy ? null : (_) => _select(section),
                                ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (_section.searchable)
                          TextField(
                            controller: _search,
                            maxLength: 120,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: 'Search metadata',
                            ),
                          ),
                        if (_section == AdminSection.audit)
                          TextField(
                            controller: _status,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'HTTP status (optional)',
                            ),
                          ),
                        TextField(
                          controller: _code,
                          enabled: !_busy,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: l10n.authenticatorCode,
                          ),
                          onSubmitted: (_) => _load(1),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : () => _load(1),
                          child: Text(
                            _authorized ? l10n.loadRefresh : l10n.verifyAccess,
                          ),
                        ),
                        if (_busy) const LinearProgressIndicator(),
                        if (_error != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (!_busy && _authorized) _data(),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
