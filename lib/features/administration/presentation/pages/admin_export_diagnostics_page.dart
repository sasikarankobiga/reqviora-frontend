import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/admin_export_diagnostics_repository.dart';
import '../../domain/admin_export_diagnostic.dart';

class AdminExportDiagnosticsPage extends ConsumerStatefulWidget {
  const AdminExportDiagnosticsPage({super.key});

  @override
  ConsumerState<AdminExportDiagnosticsPage> createState() =>
      _AdminExportDiagnosticsPageState();
}

class _AdminExportDiagnosticsPageState
    extends ConsumerState<AdminExportDiagnosticsPage> {
  final _project = TextEditingController();
  AdminExportStatus _status = AdminExportStatus.all;
  DateTime? _from;
  DateTime? _to;
  AdminExportPage? _data;
  AdminExportSummary? _summary;
  bool _busy = false;
  String? _error;
  int _operation = 0;
  int _session = authSession.generation;
  late final AdminExportDiagnosticsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = AdminExportDiagnosticsRepository(ref.read(apiClientProvider));
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_session == authSession.generation) return;
    _session = authSession.generation;
    _operation++;
    if (mounted) {
      setState(() {
        _data = null;
        _summary = null;
        _busy = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _project.dispose();
    super.dispose();
  }

  String _t(String en, String ta) => uiText(context, en, ta);
  String _date(DateTime? value) =>
      value?.toLocal().toString() ?? _t('Not available', 'கிடைக்கவில்லை');

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
      final results = await Future.wait<Object>([
        _repository.list(
          page: page,
          status: _status,
          projectId: project.isEmpty ? null : project,
          from: _from,
          to: _to,
        ),
        _repository.summary(from: _from, to: _to),
      ]);
      if (!_current(operation, session)) return;
      setState(() {
        _data = results[0] as AdminExportPage;
        _summary = results[1] as AdminExportSummary;
      });
    } on ApiException catch (error) {
      if (_current(operation, session)) {
        setState(() => _error = _apiError(error));
      }
    } on FormatException {
      if (_current(operation, session)) {
        setState(
          () =>
              _error = _t(
                'The server returned incompatible diagnostic data.',
                'பின்தளம் பொருந்தாத கண்டறிதல் தரவை வழங்கியது.',
              ),
        );
      }
    } on ArgumentError {
      if (_current(operation, session)) {
        setState(
          () =>
              _error = _t(
                'Check the project ID and date range.',
                'திட்ட அடையாளத்தையும் தேதி வரம்பையும் சரிபார்க்கவும்.',
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
    404 => _t('Export job was not found.', 'ஏற்றுமதிப் பணி கிடைக்கவில்லை.'),
    429 => _t(
      'Too many requests. Try again later.',
      'அதிக கோரிக்கைகள். பின்னர் முயலவும்.',
    ),
    _ => _t(
      'Unable to load export diagnostics.',
      'ஏற்றுமதி கண்டறிதலை ஏற்ற முடியவில்லை.',
    ),
  };

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.utc(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: (start ? _from : _to) ?? DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _from = DateTime.utc(selected.year, selected.month, selected.day);
      } else {
        _to = DateTime.utc(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }

  Future<void> _details(AdminExportDiagnostic item) async {
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
              title: Text(
                _t('Export attempt details', 'ஏற்றுமதி முயற்சி விவரங்கள்'),
              ),
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
                'The server returned incompatible diagnostic data.',
                'பின்தளம் பொருந்தாத கண்டறிதல் தரவை வழங்கியது.',
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _metadata(AdminExportDiagnostic item) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(_t('Job ID', 'பணி அடையாளம்'), item.id),
      _line(_t('Project ID', 'திட்ட அடையாளம்'), item.projectId),
      _line(
        _t('Approved revision', 'அங்கீகரிக்கப்பட்ட பதிப்பு'),
        item.approvedRevisionId,
      ),
      _line(_t('Export type', 'ஏற்றுமதி வகை'), item.exportType),
      _line(_t('Status', 'நிலை'), item.status),
      _line(_t('Created', 'உருவாக்கப்பட்டது'), _date(item.createdAt)),
      _line(_t('Started', 'தொடங்கியது'), _date(item.startedAt)),
      _line(_t('Completed', 'முடிந்தது'), _date(item.completedAt)),
      _line(
        _t('Duration', 'கால அளவு'),
        item.durationMilliseconds == null
            ? _t('Not available', 'கிடைக்கவில்லை')
            : '${item.durationMilliseconds} ms',
      ),
      _line(_t('Integrity', 'முழுமை'), item.integrityStatus),
      if (item.failureCategory != null)
        _line(_t('Failure category', 'தோல்வி வகை'), item.failureCategory!),
      if (item.failureCode != null)
        _line(_t('Failure code', 'தோல்வி குறியீடு'), item.failureCode!),
    ],
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SelectableText('$label: $value'),
  );

  Widget _metric(String label, Object value) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) return _blocked();
    final data = _data;
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Export job diagnostics', 'ஏற்றுமதி பணி கண்டறிதல்')),
        actions: [
          IconButton(
            tooltip: _t('MCP grants', 'MCP அனுமதிகள்'),
            onPressed: () => context.go('/admin/mcp-grants'),
            icon: const Icon(Icons.key_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _t(
              'Sanitized backend diagnostics only. Storage paths, archives, exceptions and private Blueprint data are never displayed.',
              'தூய்மைப்படுத்தப்பட்ட பின்தளத் தகவல்கள் மட்டும். சேமிப்புப் பாதைகள், கோப்புகள், பிழைகள் மற்றும் தனிப்பட்ட Blueprint தரவு காட்டப்படாது.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  key: const ValueKey('export-project-filter'),
                  controller: _project,
                  decoration: InputDecoration(
                    labelText: _t(
                      'Project ID (optional)',
                      'திட்ட அடையாளம் (விருப்பம்)',
                    ),
                  ),
                ),
              ),
              DropdownButton<AdminExportStatus>(
                value: _status,
                onChanged:
                    _busy ? null : (value) => setState(() => _status = value!),
                items:
                    AdminExportStatus.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
              ),
              OutlinedButton.icon(
                key: const ValueKey('export-from'),
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.date_range),
                label: Text(
                  _from == null ? _t('From', 'தொடக்கம்') : _date(_from),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('export-to'),
                onPressed: _busy ? null : () => _pick(false),
                icon: const Icon(Icons.event),
                label: Text(_to == null ? _t('To', 'முடிவு') : _date(_to)),
              ),
              FilledButton.icon(
                key: const ValueKey('export-admin-load'),
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
          if (!_busy && summary != null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  _t('Total attempts', 'மொத்த முயற்சிகள்'),
                  summary.total,
                ),
                _metric(_t('Successful', 'வெற்றிகரமானவை'), summary.successful),
                _metric(_t('Failed', 'தோல்வியுற்றவை'), summary.failed),
                _metric(
                  _t('Average duration', 'சராசரி காலம்'),
                  '${summary.averageDurationMilliseconds.toStringAsFixed(0)} ms',
                ),
                _metric(
                  _t('Integrity verified', 'முழுமை சரிபார்க்கப்பட்டது'),
                  summary.integrityVerified,
                ),
                _metric(
                  _t('Integrity failed', 'முழுமை தோல்வி'),
                  summary.integrityFailed,
                ),
              ],
            ),
          if (!_busy && data != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_t('Matching attempts', 'பொருந்தும் முயற்சிகள்')}: ${data.total}',
            ),
            if (data.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _t(
                    'No matching export attempts.',
                    'பொருந்தும் ஏற்றுமதி முயற்சிகள் இல்லை.',
                  ),
                ),
              ),
            for (final item in data.items)
              Card(
                child: ListTile(
                  title: Text('${item.status} · ${item.exportType}'),
                  subtitle: Text(
                    '${_t('Project', 'திட்டம்')}: ${item.projectId}\n${_t('Integrity', 'முழுமை')}: ${item.integrityStatus}',
                  ),
                  isThreeLine: true,
                  onTap: () => _details(item),
                  trailing: const Icon(Icons.chevron_right),
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
      title: Text(_t('Export job diagnostics', 'ஏற்றுமதி பணி கண்டறிதல்')),
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
