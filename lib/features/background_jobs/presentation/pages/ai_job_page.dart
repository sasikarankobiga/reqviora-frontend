import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../l10n/language_settings.dart';
import '../../../auth/application/auth_providers.dart';
import '../../data/repositories/ai_job_repository.dart';

class AiJobPage extends ConsumerStatefulWidget {
  const AiJobPage({super.key, this.pollInterval = const Duration(seconds: 2)});

  final Duration pollInterval;

  @override
  ConsumerState<AiJobPage> createState() => _AiJobPageState();
}

class _AiJobPageState extends ConsumerState<AiJobPage> {
  final _prompt = TextEditingController();

  AiJobStatus? _job;

  bool _consent = false;
  bool _submitting = false;
  bool _monitoring = false;

  String? _error;
  int _operation = 0;
  int _generation = authSession.generation;

  bool get _busy => _submitting || _monitoring;

  AiJobRepository get _repository =>
      AiJobRepository(ref.read(authRepositoryProvider).api);

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;
    _operation++;
    _prompt.clear();

    setState(() {
      _job = null;
      _consent = false;
      _submitting = false;
      _monitoring = false;
      _error = null;
    });
  }

  bool _active(int operation) =>
      mounted &&
      authSession.authenticated &&
      _generation == authSession.generation &&
      operation == _operation;

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!authSession.authenticated || !_consent || _busy) {
      return;
    }

    final prompt = _prompt.text.trim();

    if (prompt.isEmpty || prompt.length > 100000) {
      setState(() {
        _error = uiText(
          context,
          'Enter a valid AI prompt.',
          'சரியான AI கோரிக்கையை உள்ளிடவும்.',
        );
      });
      return;
    }

    final operation = ++_operation;

    setState(() {
      _submitting = true;
      _job = null;
      _error = null;
    });

    try {
      final job = await _repository.submit(prompt);

      if (!_active(operation)) return;

      setState(() {
        _job = job;
        _prompt.clear();
        _consent = false;
        _submitting = false;
      });

      await _monitor(job.id);
    } catch (_) {
      if (!_active(operation)) return;

      setState(() {
        _error = uiText(
          context,
          'Submission could not be confirmed. Do not retry automatically.',
          'கோரிக்கை உறுதிப்படுத்தப்படவில்லை. தானாக மீண்டும் அனுப்ப வேண்டாம்.',
        );
      });
    } finally {
      if (_active(operation)) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _monitor(String jobId) async {
    if (!authSession.authenticated || _busy) return;

    final operation = ++_operation;

    setState(() {
      _monitoring = true;
      _error = null;
    });

    try {
      final result = await _repository.poll(
        jobId,
        interval: widget.pollInterval,
        isCancelled: () => !_active(operation),
        onStatus: (status) {
          if (!_active(operation)) return;
          setState(() => _job = status);
        },
      );

      if (!_active(operation)) return;

      setState(() => _job = result);
    } on AiJobPollingCancelled {
      // Monitoring stopped locally. The server job is not cancelled.
    } on AiJobPollingTimeout {
      if (!_active(operation)) return;

      setState(() {
        _error = uiText(
          context,
          'Monitoring timed out. Resume to check the same job.',
          'கண்காணிப்பு நேரம் முடிந்தது. அதே வேலையை மீண்டும் கண்காணிக்கவும்.',
        );
      });
    } catch (_) {
      if (!_active(operation)) return;

      setState(() {
        _error = uiText(
          context,
          'Job status is unavailable. Resume to check again.',
          'வேலையின் நிலை கிடைக்கவில்லை. மீண்டும் சரிபார்க்கவும்.',
        );
      });
    } finally {
      if (_active(operation)) {
        setState(() => _monitoring = false);
      }
    }
  }

  void _stopMonitoring() {
    if (!_monitoring) return;

    _operation++;

    setState(() {
      _monitoring = false;
      _error = null;
    });
  }

  String _stateLabel(AiJobState state) {
    return switch (state) {
      AiJobState.queued => uiText(context, 'Queued', 'வரிசையில் உள்ளது'),
      AiJobState.running => uiText(context, 'Running', 'செயல்படுகிறது'),
      AiJobState.completed => uiText(context, 'Completed', 'முடிந்தது'),
      AiJobState.failed => uiText(context, 'Failed', 'தோல்வியடைந்தது'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final authenticated = authSession.authenticated;
    final job = _job;
    final unfinished = job != null && !job.isTerminal;

    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, 'AI Job Monitor', 'AI வேலை கண்காணிப்பு')),
        actions: const [LanguageSwitcher()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  uiText(context, 'AI background jobs', 'AI பின்னணி வேலைகள்'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  uiText(
                    context,
                    'Results are advisory and do not modify project requirements or approved designs.',
                    'முடிவுகள் ஆலோசனைக்கானவை. திட்டத் தேவைகள் அல்லது அங்கீகரிக்கப்பட்ட வடிவமைப்புகளை மாற்றாது.',
                  ),
                ),
                const SizedBox(height: 16),
                if (!authenticated)
                  Text(
                    uiText(
                      context,
                      'Sign in to use AI jobs.',
                      'AI வேலைகளைப் பயன்படுத்த உள்நுழையவும்.',
                    ),
                  ),
                TextField(
                  key: const ValueKey('ai-job-prompt'),
                  controller: _prompt,
                  enabled: authenticated && !_busy && !unfinished,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 100000,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'AI prompt', 'AI கோரிக்கை'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey('ai-job-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged:
                      authenticated && !_busy && !unfinished
                          ? (value) => setState(() => _consent = value ?? false)
                          : null,
                  title: Text(
                    uiText(
                      context,
                      'I consent to sending this prompt to the AI service.',
                      'இந்தக் கோரிக்கையை AI சேவைக்கு அனுப்ப ஒப்புக்கொள்கிறேன்.',
                    ),
                  ),
                  subtitle: Text(
                    uiText(
                      context,
                      'Do not include passwords or confidential credentials.',
                      'கடவுச்சொற்கள் அல்லது இரகசியச் சான்றுகளைச் சேர்க்க வேண்டாம்.',
                    ),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('ai-job-submit'),
                  onPressed:
                      authenticated && _consent && !_busy && !unfinished
                          ? _submit
                          : null,
                  child: Text(
                    _submitting
                        ? uiText(context, 'Submitting...', 'அனுப்புகிறது...')
                        : uiText(
                          context,
                          'Submit AI job',
                          'AI வேலையை அனுப்புக',
                        ),
                  ),
                ),
                if (job != null) ...[
                  const Divider(height: 32),
                  SelectableText('Job ID: ${job.id}'),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _stateLabel(job.state),
                      key: const ValueKey('ai-job-status'),
                    ),
                  ),
                  if (_monitoring) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    OutlinedButton(
                      key: const ValueKey('ai-job-stop'),
                      onPressed: _stopMonitoring,
                      child: Text(
                        uiText(
                          context,
                          'Stop monitoring',
                          'கண்காணிப்பை நிறுத்துக',
                        ),
                      ),
                    ),
                  ],
                  if (unfinished && !_busy)
                    OutlinedButton(
                      key: const ValueKey('ai-job-resume'),
                      onPressed: authenticated ? () => _monitor(job.id) : null,
                      child: Text(
                        uiText(
                          context,
                          'Resume monitoring',
                          'மீண்டும் கண்காணிக்கவும்',
                        ),
                      ),
                    ),
                  if (job.state == AiJobState.failed)
                    Text(
                      uiText(
                        context,
                        'AI provider request failed.',
                        'AI சேவைக் கோரிக்கை தோல்வியடைந்தது.',
                      ),
                    ),
                  if (job.state == AiJobState.completed)
                    SelectableText(
                      job.result ?? '',
                      key: const ValueKey('ai-job-result'),
                    ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  uiText(
                    context,
                    'Stopping monitoring does not cancel the server job. Job availability after a server restart is not guaranteed.',
                    'கண்காணிப்பை நிறுத்துவது சேவையக வேலையை ரத்து செய்யாது. சேவையகம் மீண்டும் தொடங்கிய பின் வேலை கிடைக்கும் என உறுதியில்லை.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
