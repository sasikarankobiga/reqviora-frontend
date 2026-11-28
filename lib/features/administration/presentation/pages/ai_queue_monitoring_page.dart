import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../application/admin_monitoring_providers.dart';
import '../../domain/admin_monitoring_models.dart';

class AiQueueMonitoringPage extends ConsumerStatefulWidget {
  const AiQueueMonitoringPage({
    super.key,
    this.pollInterval = const Duration(seconds: 15),
  });

  final Duration pollInterval;

  @override
  ConsumerState<AiQueueMonitoringPage> createState() =>
      _AiQueueMonitoringPageState();
}

class _AiQueueMonitoringPageState extends ConsumerState<AiQueueMonitoringPage> {
  AiQueueSnapshot? _snapshot;
  AdminAiJobStatus? _status;
  DateTime? _from;
  DateTime? _to;
  Timer? _timer;
  bool _polling = false;
  bool _busy = false;
  String? _error;
  int _page = 1;
  int _operation = 0;
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
    _operation++;
    _stopPolling();
    if (!mounted) return;
    setState(() {
      _snapshot = null;
      _busy = false;
      _error = null;
      _page = 1;
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _timer?.cancel();
    super.dispose();
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
  }

  void _togglePolling(bool enabled) {
    _stopPolling();
    if (enabled) {
      _polling = true;
      _timer = Timer.periodic(widget.pollInterval, (_) {
        if (!_busy && authSession.authenticated) {
          _load(page: _page, quiet: true);
        }
      });
    }
    setState(() {});
  }

  Future<void> _pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (start) {
        _from = selected.toUtc();
      } else {
        _to = DateTime.utc(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
        );
      }
      _page = 1;
      _error = null;
    });
  }

  Future<void> _load({int page = 1, bool quiet = false}) async {
    if (_busy || isLocalDemo || !authSession.authenticated) return;
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      setState(
        () =>
            _error = uiText(
              context,
              'The date range is invalid.',
              'தேதி வரம்பு தவறானது.',
            ),
      );
      return;
    }
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      if (!quiet) _error = null;
    });
    try {
      final result = await ref
          .read(adminMonitoringRepositoryProvider)
          .aiQueue(
            page: page,
            status: _status,
            type: 'completion',
            from: _from,
            to: _to,
          );
      if (!mounted ||
          operation != _operation ||
          generation != authSession.generation) {
        return;
      }
      setState(() {
        _snapshot = result;
        _page = page;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || operation != _operation) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        _stopPolling();
        _snapshot = null;
      }
      setState(() => _error = _safeError(error.statusCode));
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(
          () =>
              _error = uiText(
                context,
                'Unable to load the AI queue.',
                'AI வரிசையை ஏற்ற முடியவில்லை.',
              ),
        );
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  String _safeError(int status) => switch (status) {
    401 => uiText(
      context,
      'Your session expired. Sign in again.',
      'உங்கள் அமர்வு முடிந்தது. மீண்டும் உள்நுழையவும்.',
    ),
    403 => uiText(
      context,
      'Administrator access with MFA is required.',
      'MFA உடன் நிர்வாகி அணுகல் தேவை.',
    ),
    400 => uiText(
      context,
      'The selected filters are unsupported.',
      'தேர்ந்தெடுத்த வடிகட்டிகள் ஆதரிக்கப்படவில்லை.',
    ),
    0 => uiText(
      context,
      'Cannot connect to the backend.',
      'பின்தளத்துடன் இணைக்க முடியவில்லை.',
    ),
    _ => uiText(
      context,
      'Unable to load the AI queue.',
      'AI வரிசையை ஏற்ற முடியவில்லை.',
    ),
  };

  String _statusLabel(AdminAiJobStatus status) => switch (status) {
    AdminAiJobStatus.pending => uiText(context, 'Pending', 'நிலுவையில்'),
    AdminAiJobStatus.processing => uiText(
      context,
      'Processing',
      'செயலாக்கத்தில்',
    ),
    AdminAiJobStatus.completed => uiText(context, 'Completed', 'முடிந்தது'),
    AdminAiJobStatus.failed => uiText(context, 'Failed', 'தோல்வி'),
    AdminAiJobStatus.cancelled => uiText(
      context,
      'Cancelled',
      'ரத்து செய்யப்பட்டது',
    ),
  };

  String _date(DateTime? value) =>
      value == null
          ? uiText(context, 'Not available', 'கிடைக்கவில்லை')
          : value.toLocal().toString();

  Widget _stat(String label, Object value) => SizedBox(
    width: 170,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );

  Future<void> _details(AdminAiJob job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final current = await ref
          .read(adminMonitoringRepositoryProvider)
          .aiJob(job.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(
                uiText(context, 'AI job details', 'AI வேலை விவரங்கள்'),
              ),
              content: SingleChildScrollView(
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${uiText(context, 'Job ID', 'வேலை ID')}: ${current.id}',
                      ),
                      Text(
                        '${uiText(context, 'Project ID', 'திட்ட ID')}: ${current.projectId}',
                      ),
                      Text(
                        '${uiText(context, 'Status', 'நிலை')}: ${_statusLabel(current.status)}',
                      ),
                      Text(
                        '${uiText(context, 'Attempts', 'முயற்சிகள்')}: ${current.attempts}/${current.maxAttempts}',
                      ),
                      Text(
                        '${uiText(context, 'Created', 'உருவாக்கப்பட்டது')}: ${_date(current.createdAt)}',
                      ),
                      Text(
                        '${uiText(context, 'Started', 'தொடங்கியது')}: ${_date(current.startedAt)}',
                      ),
                      Text(
                        '${uiText(context, 'Completed', 'முடிந்தது')}: ${_date(current.completedAt)}',
                      ),
                      Text(
                        '${uiText(context, 'Duration', 'கால அளவு')}: ${current.durationMilliseconds ?? '-'} ms',
                      ),
                      Text(
                        '${uiText(context, 'Failure category', 'தோல்வி வகை')}: ${current.failureCategory ?? '-'}',
                      ),
                      Text(
                        '${uiText(context, 'Stale', 'காலாவதி')}: ${current.stale}',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(uiText(context, 'Close', 'மூடு')),
                ),
              ],
            ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = _safeError(error.statusCode));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            uiText(context, 'AI queue monitoring', 'AI வரிசை கண்காணிப்பு'),
          ),
        ),
        body: Center(
          child: Text(
            uiText(
              context,
              'Real administrator authentication is required.',
              'உண்மையான நிர்வாகி அங்கீகாரம் தேவை.',
            ),
          ),
        ),
      );
    }
    final snapshot = _snapshot;
    final jobs = snapshot?.jobs;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          uiText(context, 'AI queue monitoring', 'AI வரிசை கண்காணிப்பு'),
        ),
        actions: [
          const LanguageSwitcher(),
          TextButton(
            onPressed: () => context.go('/administration'),
            child: Text(uiText(context, 'Administration', 'நிர்வாகம்')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            uiText(
              context,
              'Advanced AI queue monitoring',
              'மேம்பட்ட AI வரிசை கண்காணிப்பு',
            ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            uiText(
              context,
              'Only sanitized lifecycle metadata is displayed. Prompts, responses, credentials and provider keys are never returned.',
              'பாதுகாப்பான வாழ்க்கைச்சுழற்சி தகவல் மட்டுமே காட்டப்படும். Prompt, பதில், சான்றுகள் மற்றும் provider keys திருப்பப்படாது.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<AdminAiJobStatus?>(
                key: const ValueKey('ai-queue-status'),
                value: _status,
                hint: Text(
                  uiText(context, 'All statuses', 'அனைத்து நிலைகளும்'),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      uiText(context, 'All statuses', 'அனைத்து நிலைகளும்'),
                    ),
                  ),
                  for (final status in AdminAiJobStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                ],
                onChanged:
                    _busy
                        ? null
                        : (value) => setState(() {
                          _status = value;
                          _page = 1;
                        }),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _pick(true),
                child: Text(
                  '${uiText(context, 'From', 'முதல்')}: ${_from == null ? '-' : _from!.toIso8601String().substring(0, 10)}',
                ),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _pick(false),
                child: Text(
                  '${uiText(context, 'To', 'வரை')}: ${_to == null ? '-' : _to!.toIso8601String().substring(0, 10)}',
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('ai-queue-refresh'),
                onPressed: _busy ? null : () => _load(),
                icon: const Icon(Icons.refresh),
                label: Text(uiText(context, 'Refresh', 'புதுப்பிக்கவும்')),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: const ValueKey('ai-queue-polling'),
                    value: _polling,
                    onChanged: _busy ? null : _togglePolling,
                  ),
                  Text(
                    uiText(context, 'Auto refresh', 'தானியங்கி புதுப்பிப்பு'),
                  ),
                ],
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (snapshot != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat(
                  uiText(context, 'Pending', 'நிலுவையில்'),
                  snapshot.statistics.pending,
                ),
                _stat(
                  uiText(context, 'Processing', 'செயலாக்கத்தில்'),
                  snapshot.statistics.processing,
                ),
                _stat(
                  uiText(context, 'Completed', 'முடிந்தது'),
                  snapshot.statistics.completed,
                ),
                _stat(
                  uiText(context, 'Failed', 'தோல்வி'),
                  snapshot.statistics.failed,
                ),
                _stat(
                  uiText(context, 'Cancelled', 'ரத்து'),
                  snapshot.statistics.cancelled,
                ),
                _stat(
                  uiText(context, 'Timeouts', 'நேர முடிவுகள்'),
                  snapshot.statistics.timeouts,
                ),
                _stat(
                  uiText(context, 'Retry attempts', 'மறு முயற்சிகள்'),
                  snapshot.statistics.retryAttempts,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    Text(
                      '${uiText(context, 'Provider', 'வழங்குநர்')}: ${snapshot.health.providerStatus}',
                    ),
                    Text(
                      '${uiText(context, 'Worker', 'செயலி')}: ${snapshot.health.localWorkerStatus}',
                    ),
                    Text(
                      '${uiText(context, 'Queue', 'வரிசை')}: ${snapshot.health.queueStatus}',
                    ),
                    Text(
                      '${uiText(context, 'Stale jobs', 'காலாவதியான வேலைகள்')}: ${snapshot.health.staleJobs}',
                    ),
                    Text(
                      '${uiText(context, 'Last poll', 'கடைசி கணிப்பு')}: ${_date(snapshot.health.lastLocalPoll)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (jobs!.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  uiText(
                    context,
                    'No AI jobs match these filters.',
                    'இந்த வடிகட்டிகளுக்கு AI வேலைகள் இல்லை.',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final job in jobs.items)
                Card(
                  child: ListTile(
                    key: ValueKey('ai-queue-job-${job.id}'),
                    title: Text('${job.type} · ${_statusLabel(job.status)}'),
                    subtitle: Text(
                      '${uiText(context, 'Project', 'திட்டம்')}: ${job.projectId}\n${uiText(context, 'Attempts', 'முயற்சிகள்')}: ${job.attempts}/${job.maxAttempts} · ${_date(job.createdAt)}${job.failureCategory == null ? '' : '\n${uiText(context, 'Failure category', 'தோல்வி வகை')}: ${job.failureCategory}'}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: uiText(
                        context,
                        'Inspect job',
                        'வேலையைப் பார்வையிடு',
                      ),
                      onPressed: _busy ? null : () => _details(job),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ),
                ),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed:
                      _busy || _page <= 1 ? null : () => _load(page: _page - 1),
                  child: Text(uiText(context, 'Previous', 'முந்தைய')),
                ),
                Text(
                  '${uiText(context, 'Page', 'பக்கம்')} $_page · ${jobs.total} ${uiText(context, 'jobs', 'வேலைகள்')}',
                ),
                OutlinedButton(
                  onPressed:
                      _busy || _page * jobs.pageSize >= jobs.total
                          ? null
                          : () => _load(page: _page + 1),
                  child: Text(uiText(context, 'Next', 'அடுத்தது')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              uiText(
                context,
                'Administrative retry, cancellation and provider configuration are not exposed by the current backend API. No unsupported action is simulated.',
                'நிர்வாக மறு முயற்சி, ரத்து மற்றும் provider அமைப்பு தற்போதைய பின்தள API-ல் இல்லை. ஆதரிக்கப்படாத செயல் உருவகப்படுத்தப்படாது.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (!_busy && _error == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                uiText(
                  context,
                  'Load the real AI queue to begin monitoring.',
                  'கண்காணிப்பைத் தொடங்க உண்மையான AI வரிசையை ஏற்றவும்.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
