import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/admin_settings_incidents_repository.dart';
import '../../domain/admin_settings_incidents.dart';

class AdminSettingsIncidentsPage extends ConsumerStatefulWidget {
  const AdminSettingsIncidentsPage({super.key});
  @override
  ConsumerState<AdminSettingsIncidentsPage> createState() => _State();
}

class _State extends ConsumerState<AdminSettingsIncidentsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final AdminSettingsIncidentsRepository _repo;
  final _value = TextEditingController(),
      _reason = TextEditingController(),
      _search = TextEditingController(),
      _category = TextEditingController(),
      _assignee = TextEditingController();
  PlatformSetting? _setting;
  List<SettingHistoryEntry> _history = [];
  IncidentPage? _incidents;
  IncidentSummary? _summary;
  IncidentPriority? _priority;
  IncidentStatus? _status;
  bool _busy = false;
  String? _error, _notice;
  int _operation = 0;
  int _historyPage = 1;
  String t(String en, String ta) => uiText(context, en, ta);
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _repo = AdminSettingsIncidentsRepository(ref.read(apiClientProvider));
    authSession.addListener(_session);
  }

  void _session() {
    _operation++;
    if (mounted)
      setState(() {
        _setting = null;
        _incidents = null;
        _busy = false;
      });
  }

  @override
  void dispose() {
    authSession.removeListener(_session);
    _tabs.dispose();
    _value.dispose();
    _reason.dispose();
    _search.dispose();
    _category.dispose();
    _assignee.dispose();
    super.dispose();
  }

  bool current(int op, int gen) =>
      mounted &&
      op == _operation &&
      gen == authSession.generation &&
      authSession.authenticated;
  String safe(Object e) =>
      e is ApiException
          ? switch (e.statusCode) {
            401 => t(
              'Authentication or administrator MFA is required.',
              'உள்நுழைவும் நிர்வாகி MFA-வும் தேவை.',
            ),
            403 => t(
              'Administrator access is not authorized.',
              'நிர்வாகி அணுகல் அனுமதிக்கப்படவில்லை.',
            ),
            409 => t(
              'The record changed. Refresh and retry.',
              'பதிவு மாறியுள்ளது. புதுப்பித்து மீண்டும் முயலவும்.',
            ),
            _ => t(
              'The operation could not be completed.',
              'செயலை முடிக்க முடியவில்லை.',
            ),
          }
          : t(
            'Check the entered values and retry.',
            'உள்ளிட்ட மதிப்புகளைச் சரிபார்த்து மீண்டும் முயலவும்.',
          );
  Future<void> loadSettings([int historyPage = 1]) async {
    if (_busy) return;
    final op = ++_operation, gen = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final r = await Future.wait([
        _repo.settings(),
        _repo.settingHistory(page: historyPage),
      ]);
      if (!current(op, gen)) return;
      final s = (r[0] as List<PlatformSetting>).single;
      setState(() {
        _setting = s;
        _history = r[1] as List<SettingHistoryEntry>;
        _historyPage = historyPage;
        _value.text = '${s.value}';
      });
    } catch (e) {
      if (current(op, gen)) setState(() => _error = safe(e));
    } finally {
      if (current(op, gen)) setState(() => _busy = false);
    }
  }

  Future<void> updateSetting({int? rollback}) async {
    final s = _setting;
    if (_busy || s == null) return;
    final reason = _reason.text.trim();
    final value = int.tryParse(_value.text.trim());
    if (rollback == null &&
            (value == null || value < s.minimum || value > s.maximum) ||
        reason.length < 3) {
      setState(
        () =>
            _error = t(
              'Enter a supported value and a reason of at least 3 characters.',
              'ஆதரிக்கப்படும் மதிப்பையும் குறைந்தது 3 எழுத்து காரணத்தையும் உள்ளிடவும்.',
            ),
      );
      return;
    }
    final ok =
        await showDialog<bool>(
          context: context,
          builder:
              (c) => AlertDialog(
                title: Text(
                  rollback == null
                      ? t(
                        'Confirm setting change',
                        'அமைப்பு மாற்றத்தை உறுதிப்படுத்து',
                      )
                      : t('Confirm rollback', 'மீட்டமைப்பை உறுதிப்படுத்து'),
                ),
                content: Text(
                  t(
                    'This administrator action is audited.',
                    'இந்த நிர்வாகி செயல் தணிக்கை செய்யப்படும்.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(t('Cancel', 'ரத்து')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(t('Confirm', 'உறுதிப்படுத்து')),
                  ),
                ],
              ),
        ) ??
        false;
    if (!ok) return;
    setState(() => _busy = true);
    try {
      if (rollback == null) {
        await _repo.updateSetting(
          value: value!,
          expectedRevision: s.revision,
          reason: reason,
        );
      } else {
        await _repo.rollbackSetting(
          targetRevision: rollback,
          expectedRevision: s.revision,
          reason: reason,
        );
      }
      if (!mounted) return;
      _reason.clear();
      _notice = t(
        'Backend confirmed the setting change.',
        'அமைப்பு மாற்றத்தை பின்தளம் உறுதிப்படுத்தியது.',
      );
      setState(() => _busy = false);
      await loadSettings();
      return;
    } catch (e) {
      if (mounted) setState(() => _error = safe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> loadIncidents([int page = 1]) async {
    if (_busy) return;
    final op = ++_operation, gen = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final r = await _repo.incidents(
        search: _search.text,
        category: _category.text,
        priority: _priority,
        status: _status,
        assignedAdminId:
            _assignee.text.trim().isEmpty ? null : _assignee.text.trim(),
        page: page,
      );
      if (current(op, gen))
        setState(() {
          _incidents = r.$1;
          _summary = r.$2;
        });
    } catch (e) {
      if (current(op, gen)) setState(() => _error = safe(e));
    } finally {
      if (current(op, gen)) setState(() => _busy = false);
    }
  }

  Future<void> createIncident() async {
    final category = TextEditingController(),
        correlation = TextEditingController();
    var priority = IncidentPriority.medium;
    final submit =
        await showDialog<bool>(
          context: context,
          builder:
              (c) => StatefulBuilder(
                builder:
                    (c, set) => AlertDialog(
                      title: Text(t('Create incident', 'சம்பவத்தை உருவாக்கு')),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: category,
                            maxLength: 80,
                            decoration: InputDecoration(
                              labelText: t('Category', 'வகை'),
                            ),
                          ),
                          DropdownButton<IncidentPriority>(
                            value: priority,
                            items:
                                IncidentPriority.values
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(priorityWire(v)),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => set(() => priority = v!),
                          ),
                          TextField(
                            controller: correlation,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: t(
                                'Correlation ID (optional)',
                                'தொடர்பு ID (விருப்பம்)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(t('Cancel', 'ரத்து')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(t('Create', 'உருவாக்கு')),
                        ),
                      ],
                    ),
              ),
        ) ??
        false;
    if (submit) {
      setState(() => _busy = true);
      try {
        await _repo.createIncident(
          category: category.text,
          priority: priority,
          correlationId: correlation.text,
        );
        if (mounted) {
          _notice = t(
            'Incident created by the backend.',
            'சம்பவம் பின்தளத்தால் உருவாக்கப்பட்டது.',
          );
          setState(() => _busy = false);
          await loadIncidents();
          return;
        }
      } catch (e) {
        if (mounted) setState(() => _error = safe(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    category.dispose();
    correlation.dispose();
  }

  Future<void> details(IncidentDetails item) async {
    setState(() => _busy = true);
    try {
      final r = await _repo.incident(item.id);
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder:
            (c) => _IncidentDialog(
              item: r.$1,
              history: r.$2,
              repo: _repo,
              onChanged: () {
                Navigator.pop(c);
                loadIncidents();
              },
            ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = safe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated)
      return Scaffold(
        body: Center(
          child: Text(
            t(
              'Authenticated administrator access is required.',
              'உள்நுழைந்த நிர்வாகி அணுகல் தேவை.',
            ),
          ),
        ),
      );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Settings and incidents', 'அமைப்புகள் மற்றும் சம்பவங்கள்'),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: t('Platform settings', 'தள அமைப்புகள்')),
            Tab(text: t('Incidents', 'சம்பவங்கள்')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/administration'),
            child: Text(t('Administration', 'நிர்வாகம்')),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [settingsView(), incidentsView()],
      ),
    );
  }

  Widget messages() => Column(
    children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_notice != null)
        Padding(padding: const EdgeInsets.all(8), child: Text(_notice!)),
    ],
  );
  Widget settingsView() {
    final s = _setting;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t(
            'Only the backend-allowlisted document upload limit is editable. Secrets and environment variables are never exposed.',
            'பின்தளம் அனுமதித்த ஆவண பதிவேற்ற வரம்பு மட்டும் திருத்தக்கூடியது. ரகசியங்கள் காட்டப்படாது.',
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('settings-load'),
          onPressed: _busy ? null : loadSettings,
          icon: const Icon(Icons.refresh),
          label: Text(t('Refresh', 'புதுப்பி')),
        ),
        messages(),
        if (s != null) ...[
          Text(
            '${s.key} · ${t('Revision', 'பதிப்பு')}: ${s.revision} · ${s.minimum}–${s.maximum} bytes',
          ),
          TextField(
            key: const ValueKey('settings-value'),
            controller: _value,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: t(
                'Document upload maximum bytes',
                'ஆவண பதிவேற்ற அதிகபட்ச bytes',
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (int.tryParse(_value.text.trim()) != s.value)
            Text(
              t('Unsaved setting change', 'சேமிக்கப்படாத அமைப்பு மாற்றம்'),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          TextField(
            key: const ValueKey('settings-reason'),
            controller: _reason,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: t('Administrative reason', 'நிர்வாக காரணம்'),
            ),
          ),
          FilledButton(
            key: const ValueKey('settings-update'),
            onPressed: _busy ? null : () => updateSetting(),
            child: Text(t('Confirm update', 'மாற்றத்தை உறுதிப்படுத்து')),
          ),
          const SizedBox(height: 16),
          Text(
            t('Version history', 'பதிப்பு வரலாறு'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_history.isEmpty)
            Text(t('No setting changes yet.', 'அமைப்பு மாற்றங்கள் இல்லை.')),
          for (final h in _history)
            Card(
              child: ListTile(
                title: Text(
                  '${t('Revision', 'பதிப்பு')} ${h.revision}: ${h.previousValue} → ${h.value}',
                ),
                subtitle: Text(
                  '${h.changedAt.toLocal()} · ${h.changedBy}\n${h.reason}'
                  '${h.rolledBackTo == null ? '' : '\nRollback → revision ${h.rolledBackTo}'}',
                ),
                isThreeLine: true,
                trailing:
                    h.revision < s.revision
                        ? TextButton(
                          onPressed:
                              _busy
                                  ? null
                                  : () => updateSetting(rollback: h.revision),
                          child: Text(t('Rollback', 'மீட்டமை')),
                        )
                        : null,
              ),
            ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed:
                    _busy || _historyPage <= 1
                        ? null
                        : () => loadSettings(_historyPage - 1),
                child: Text(t('Previous', 'முந்தையது')),
              ),
              Text('${t('History page', 'வரலாற்றுப் பக்கம்')} $_historyPage'),
              OutlinedButton(
                onPressed:
                    _busy || _history.length < 20
                        ? null
                        : () => loadSettings(_historyPage + 1),
                child: Text(t('Next', 'அடுத்தது')),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget incidentsView() {
    final d = _incidents, s = _summary;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t(
            'Support-ticket APIs are not available. This page shows backend-authoritative operational incidents only.',
            'ஆதரவு ticket API இல்லை. பின்தளத்தின் உண்மையான செயல்பாட்டு சம்பவங்கள் மட்டும் காட்டப்படும்.',
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: _search,
                decoration: InputDecoration(labelText: t('Search', 'தேடு')),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _category,
                maxLength: 80,
                decoration: InputDecoration(labelText: t('Category', 'வகை')),
              ),
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _assignee,
                decoration: InputDecoration(
                  labelText: t(
                    'Assigned administrator ID',
                    'ஒதுக்கப்பட்ட நிர்வாகி ID',
                  ),
                ),
              ),
            ),
            DropdownButton<IncidentPriority?>(
              value: _priority,
              hint: Text(t('All priorities', 'அனைத்து முன்னுரிமைகள்')),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final v in IncidentPriority.values)
                  DropdownMenuItem(value: v, child: Text(priorityWire(v))),
              ],
              onChanged: (v) => setState(() => _priority = v),
            ),
            DropdownButton<IncidentStatus?>(
              value: _status,
              hint: Text(t('All statuses', 'அனைத்து நிலைகள்')),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final v in IncidentStatus.values)
                  DropdownMenuItem(value: v, child: Text(statusWire(v))),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            FilledButton.icon(
              key: const ValueKey('incidents-load'),
              onPressed: _busy ? null : () => loadIncidents(),
              icon: const Icon(Icons.refresh),
              label: Text(t('Refresh', 'புதுப்பி')),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : createIncident,
              icon: const Icon(Icons.add),
              label: Text(t('Create incident', 'சம்பவத்தை உருவாக்கு')),
            ),
          ],
        ),
        messages(),
        if (s != null)
          Wrap(
            spacing: 12,
            children: [
              Text('Open: ${s.open}'),
              Text('In progress: ${s.inProgress}'),
              Text('Critical: ${s.critical}'),
              Text('Total: ${s.total}'),
            ],
          ),
        if (d != null) ...[
          if (d.items.isEmpty)
            Text(t('No matching incidents.', 'பொருந்தும் சம்பவங்கள் இல்லை.')),
          for (final i in d.items)
            Card(
              child: ListTile(
                title: Text('${i.reference} · ${i.category}'),
                subtitle: Text(
                  '${priorityWire(i.priority)} · ${statusWire(i.status)}\n${i.updatedAt.toLocal()}',
                ),
                isThreeLine: true,
                onTap: () => details(i),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed:
                    _busy || d.page <= 1
                        ? null
                        : () => loadIncidents(d.page - 1),
                child: Text(t('Previous', 'முந்தையது')),
              ),
              Text('${t('Page', 'பக்கம்')} ${d.page} · ${d.total}'),
              OutlinedButton(
                onPressed:
                    _busy || d.page * d.pageSize >= d.total
                        ? null
                        : () => loadIncidents(d.page + 1),
                child: Text(t('Next', 'அடுத்தது')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _IncidentDialog extends StatefulWidget {
  const _IncidentDialog({
    required this.item,
    required this.history,
    required this.repo,
    required this.onChanged,
  });
  final IncidentDetails item;
  final List<IncidentHistoryEntry> history;
  final AdminSettingsIncidentsRepository repo;
  final VoidCallback onChanged;
  @override
  State<_IncidentDialog> createState() => _IncidentDialogState();
}

class _IncidentDialogState extends State<_IncidentDialog> {
  late IncidentStatus status = widget.item.status;
  final notes = TextEditingController(), assignee = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    notes.dispose();
    assignee.dispose();
    super.dispose();
  }

  Future<void> change() async {
    setState(() => busy = true);
    try {
      await widget.repo.changeStatus(
        widget.item,
        status,
        resolutionNotes: notes.text,
      );
      widget.onChanged();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> assign() async {
    setState(() => busy = true);
    try {
      await widget.repo.assign(
        widget.item,
        assignee.text.trim().isEmpty ? null : assignee.text.trim(),
      );
      widget.onChanged();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${widget.item.reference} · ${widget.item.category}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            'Reporter: ${widget.item.reporterId}\nAssigned: ${widget.item.assignedAdminId ?? '-'}\nCreated: ${widget.item.createdAt.toLocal()}\nResolution: ${widget.item.resolutionNotes ?? '-'}',
          ),
          const Divider(),
          for (final h in widget.history)
            Text(
              '${h.changedAt.toLocal()} · ${h.action}: ${h.notes ?? h.newValue ?? '-'}',
            ),
          DropdownButton<IncidentStatus>(
            value: status,
            items:
                IncidentStatus.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(statusWire(v)),
                      ),
                    )
                    .toList(),
            onChanged: busy ? null : (v) => setState(() => status = v!),
          ),
          TextField(
            controller: notes,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Resolution notes'),
          ),
          FilledButton(
            onPressed: busy ? null : change,
            child: const Text('Confirm status change'),
          ),
          TextField(
            controller: assignee,
            decoration: const InputDecoration(
              labelText: 'Administrator ID (blank to unassign)',
            ),
          ),
          FilledButton(
            onPressed: busy ? null : assign,
            child: const Text('Confirm assignment'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
