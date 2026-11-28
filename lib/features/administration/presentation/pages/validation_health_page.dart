import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../application/admin_monitoring_providers.dart';
import '../../domain/admin_monitoring_models.dart';

class ValidationHealthPage extends ConsumerStatefulWidget {
  const ValidationHealthPage({super.key});

  @override
  ConsumerState<ValidationHealthPage> createState() =>
      _ValidationHealthPageState();
}

class _ValidationHealthPageState extends ConsumerState<ValidationHealthPage> {
  ValidationHealthSnapshot? _snapshot;
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;
  String? _error;
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
    if (!mounted) return;
    setState(() {
      _snapshot = null;
      _busy = false;
      _error = null;
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    super.dispose();
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
        _from = selected;
      } else {
        _to = selected;
      }
      _error = null;
    });
  }

  Future<void> _load() async {
    if (_busy || isLocalDemo || !authSession.authenticated) return;
    if (_from != null && _to != null && _from!.isAfter(_to!)) {
      setState(
        () =>
            _error = uiText(
              context,
              'The start date must not be after the end date.',
              'தொடக்க தேதி முடிவு தேதிக்குப் பிறகு இருக்கக்கூடாது.',
            ),
      );
      return;
    }
    final operation = ++_operation;
    final generation = authSession.generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminMonitoringRepositoryProvider)
          .validationHealth(from: _from, to: _to);
      if (!mounted ||
          operation != _operation ||
          generation != authSession.generation) {
        return;
      }
      setState(() => _snapshot = result);
    } on ApiException catch (error) {
      if (!mounted || operation != _operation) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        _snapshot = null;
      }
      setState(() => _error = _safeError(error.statusCode));
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(
          () =>
              _error = uiText(
                context,
                'Unable to load validation health.',
                'சரிபார்ப்பு நிலையை ஏற்ற முடியவில்லை.',
              ),
        );
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _busy = false);
      }
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
      'The selected date range is not supported.',
      'தேர்ந்தெடுத்த தேதி வரம்பு ஆதரிக்கப்படவில்லை.',
    ),
    0 => uiText(
      context,
      'Cannot connect to the backend.',
      'பின்தளத்துடன் இணைக்க முடியவில்லை.',
    ),
    _ => uiText(
      context,
      'Unable to load validation health.',
      'சரிபார்ப்பு நிலையை ஏற்ற முடியவில்லை.',
    ),
  };

  String _day(DateTime? value) =>
      value == null
          ? uiText(context, 'Any date', 'எந்த தேதியும்')
          : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Widget _metric(String label, String value, IconData icon) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    ),
  );

  Widget _category(String label, int count) => ListTile(
    dense: true,
    title: Text(label),
    trailing: Text(
      '$count',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (isLocalDemo || !authSession.authenticated) {
      return _accessRequired(context);
    }
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, 'Validation health', 'சரிபார்ப்பு நிலை')),
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
              'Backend-authoritative validation telemetry',
              'பின்தள அதிகாரப்பூர்வ சரிபார்ப்பு அளவீடுகள்',
            ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            uiText(
              context,
              'Only aggregate, sanitized telemetry is returned. Blueprint contents and private requirements are never displayed.',
              'ஒருங்கிணைந்த பாதுகாப்பான அளவீடுகள் மட்டுமே காட்டப்படும். Blueprint உள்ளடக்கமும் தனிப்பட்ட தேவைகளும் காட்டப்படாது.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('validation-from'),
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  '${uiText(context, 'From', 'முதல்')}: ${_day(_from)}',
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('validation-to'),
                onPressed: _busy ? null : () => _pick(false),
                icon: const Icon(Icons.event),
                label: Text('${uiText(context, 'To', 'வரை')}: ${_day(_to)}'),
              ),
              TextButton(
                onPressed:
                    _busy
                        ? null
                        : () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                child: Text(
                  uiText(context, 'Clear filters', 'வடிகட்டிகளை அகற்று'),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('validation-refresh'),
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: Text(uiText(context, 'Refresh', 'புதுப்பிக்கவும்')),
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
          if (!_busy && snapshot == null && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                uiText(
                  context,
                  'Select an optional date range and load validation health.',
                  'விருப்பமான தேதி வரம்பைத் தேர்ந்து சரிபார்ப்பு நிலையை ஏற்றவும்.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (snapshot != null) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric(
                  uiText(context, 'Attempts', 'முயற்சிகள்'),
                  '${snapshot.summary.attempts}',
                  Icons.rule,
                ),
                _metric(
                  uiText(context, 'Succeeded', 'வெற்றி'),
                  '${snapshot.summary.succeeded}',
                  Icons.check_circle,
                ),
                _metric(
                  uiText(context, 'Failed', 'தோல்வி'),
                  '${snapshot.summary.failed}',
                  Icons.error,
                ),
                _metric(
                  uiText(context, 'Success rate', 'வெற்றி விகிதம்'),
                  '${snapshot.summary.successRate.toStringAsFixed(1)}%',
                  Icons.monitor_heart,
                ),
                _metric(
                  uiText(context, 'Average duration', 'சராசரி நேரம்'),
                  '${snapshot.summary.averageDurationMilliseconds.toStringAsFixed(1)} ms',
                  Icons.timer,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      uiText(context, 'Error categories', 'பிழை வகைகள்'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _category(
                      uiText(context, 'Schema', 'கட்டமைப்பு'),
                      snapshot.summary.errors.schema,
                    ),
                    _category(
                      uiText(
                        context,
                        'Broken references',
                        'துண்டிக்கப்பட்ட குறிப்புகள்',
                      ),
                      snapshot.summary.errors.brokenReferences,
                    ),
                    _category(
                      uiText(
                        context,
                        'Unsupported components',
                        'ஆதரிக்கப்படாத கூறுகள்',
                      ),
                      snapshot.summary.errors.unsupportedComponents,
                    ),
                    _category(
                      uiText(context, 'Navigation', 'வழிசெலுத்தல்'),
                      snapshot.summary.errors.navigation,
                    ),
                    _category(
                      uiText(context, 'Other', 'பிற'),
                      snapshot.summary.errors.other,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              uiText(context, 'Daily trends', 'தினசரி போக்குகள்'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (snapshot.trends.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  uiText(
                    context,
                    'No validation attempts in this date range.',
                    'இந்த தேதி வரம்பில் சரிபார்ப்பு முயற்சிகள் இல்லை.',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final day in snapshot.trends)
                Card(
                  child: ListTile(
                    title: Text(_day(day.date)),
                    subtitle: Text(
                      '${uiText(context, 'Average', 'சராசரி')}: ${day.statistics.averageDurationMilliseconds.toStringAsFixed(1)} ms',
                    ),
                    trailing: Text(
                      '${day.statistics.succeeded}/${day.statistics.attempts}',
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            Text(
              uiText(
                context,
                'Project-level attempts, rule identifiers, warning severity and searchable diagnostics are not exposed by the current backend contract.',
                'திட்ட அளவிலான முயற்சிகள், விதி அடையாளங்கள், எச்சரிக்கை தீவிரம் மற்றும் தேடக்கூடிய விவரங்கள் தற்போதைய பின்தள ஒப்பந்தத்தில் இல்லை.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _accessRequired(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Validation health', 'சரிபார்ப்பு நிலை')),
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
