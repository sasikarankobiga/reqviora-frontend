import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../workspace/application/workspace_providers.dart';

class ClarificationDialog extends ConsumerStatefulWidget {
  const ClarificationDialog({
    super.key,
    required this.projectId,
    required this.draftVersion,
    this.requirementId,
    this.readOnly = false,
  });

  final String projectId;
  final int draftVersion;
  final String? requirementId;
  final bool readOnly;

  @override
  ConsumerState<ClarificationDialog> createState() =>
      _ClarificationDialogState();
}

class _ClarificationDialogState extends ConsumerState<ClarificationDialog> {
  final _question = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _sync;

  String? _error;
  String? _notice;

  bool _busy = false;
  bool _loaded = false;
  bool _writeBlocked = false;

  late int _expectedVersion;
  late int _sessionGeneration;

  bool get _sessionValid => authSession.generation == _sessionGeneration;

  bool get _canWrite =>
      !_busy && !widget.readOnly && !_writeBlocked && _sessionValid;

  @override
  void initState() {
    super.initState();
    _expectedVersion = widget.draftVersion;
    _sessionGeneration = authSession.generation;
    authSession.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted || _sessionValid) return;

    setState(() {
      _items = [];
      _sync = null;
      _notice = null;
      _writeBlocked = true;
      _error = 'Your session changed. Close this dialog and sign in again.';
    });
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _question.dispose();
    super.dispose();
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Your session has expired. Sign in again.',
        403 => 'You do not have permission for this operation.',
        404 => 'The requested server record is not available.',
        409 => 'The draft changed or is approved. Close and reload.',
        429 => 'Too many requests. Try again later.',
        503 => 'The server service is temporarily unavailable.',
        _ => 'The server request failed (HTTP ${error.statusCode}).',
      };
    }

    return 'Unable to complete this operation. Reload and try again.';
  }

  Future<void> _run(
    Future<void> Function() operation, {
    bool writes = false,
  }) async {
    if (_busy || !_sessionValid) return;

    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      await operation();
    } catch (error) {
      if (mounted && _sessionValid) {
        setState(() {
          _error = _describeError(error);

          if (writes) {
            _writeBlocked = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refreshList() async {
    final items = await ref
        .read(aiIntelligenceRepositoryProvider)
        .getClarifications(widget.projectId);

    if (!mounted || !_sessionValid) return;

    setState(() {
      _items = items;
      _loaded = true;
    });
  }

  Future<void> _loadSync() => _run(() async {
    setState(() => _sync = null);

    final result = await ref
        .read(aiIntelligenceRepositoryProvider)
        .getReviewSyncStatus(widget.projectId);

    if (!mounted || !_sessionValid) return;

    setState(() => _sync = result);
  });

  Future<String?> _currentToken() async {
    final repository = ref.read(aiIntelligenceRepositoryProvider);

    dynamic result;

    try {
      result = await repository.api.get(
        '/api/projects/${widget.projectId}/drafts/current',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404 && _expectedVersion == 0) {
        return null;
      }

      rethrow;
    }

    if (result is! Map ||
        result['version'] != _expectedVersion ||
        result['approvedRevisionId'] != null) {
      throw const ApiException(409, 'Draft version conflict');
    }

    final token = result['concurrencyToken'];

    if (token is! String || token.isEmpty) {
      throw const FormatException('Invalid concurrency token');
    }

    return token;
  }

  void _acceptReceipt(Map<String, dynamic> receipt) {
    final version = receipt['version'];

    if (version is! int || version != _expectedVersion + 1) {
      throw const FormatException('Unexpected saved version');
    }

    _expectedVersion = version;
  }

  Future<void> _create() async {
    final question = _question.text.trim();

    if (!_canWrite ||
        widget.requirementId == null ||
        question.isEmpty ||
        question.length > 1500) {
      return;
    }

    await _run(() async {
      final repository = ref.read(aiIntelligenceRepositoryProvider);

      final token = await _currentToken();

      if (!mounted || !_sessionValid) return;

      final receipt = await repository.createClarification(
        projectId: widget.projectId,
        requirementId: widget.requirementId!,
        question: question,
        expectedConcurrencyToken: token,
      );

      if (!mounted || !_sessionValid) return;

      _acceptReceipt(receipt);
      _question.clear();

      await _refreshList();

      if (mounted && _sessionValid) {
        setState(() {
          _sync = null;
          _notice = 'Clarification saved. Requirement approval is unchanged.';
        });
      }
    }, writes: true);
  }

  Future<void> _answer(Map<String, dynamic> item) async {
    if (!_canWrite || item['answer'] != null) return;

    final id = item['id'];
    final revision = item['revision'];

    if (id is! String || revision is! int || revision < 1) {
      return;
    }

    var answer = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const LocalizedUiText('Answer clarification'),
            content: TextFormField(
              minLines: 3,
              maxLines: 5,
              maxLength: 1500,
              onChanged: (value) => answer = value,
              decoration: InputDecoration(
                labelText: uiText(context, 'Your answer', 'உங்கள் பதில்'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const LocalizedUiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const LocalizedUiText('Submit answer'),
              ),
            ],
          ),
    );

    if (!mounted ||
        !_canWrite ||
        confirmed != true ||
        answer.trim().isEmpty ||
        answer.trim().length > 1500) {
      return;
    }

    await _run(() async {
      final repository = ref.read(aiIntelligenceRepositoryProvider);

      final token = await _currentToken();

      if (!mounted || !_sessionValid) return;

      if (token == null) {
        throw const FormatException('Missing saved draft');
      }

      final receipt = await repository.answerClarification(
        projectId: widget.projectId,
        questionId: id,
        expectedConcurrencyToken: token,
        expectedRevision: revision,
        answer: answer.trim(),
      );

      if (!mounted || !_sessionValid) return;

      _acceptReceipt(receipt);

      await _refreshList();

      if (mounted && _sessionValid) {
        setState(() {
          _sync = null;
          _notice = 'Answer saved. A separate review decision is required.';
        });
      }
    }, writes: true);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items.where(
      (item) =>
          widget.requirementId == null ||
          item['requirementId'] == widget.requirementId,
    );

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          widget.requirementId == null
              ? 'Review synchronization'
              : 'Requirement clarifications',
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.requirementId != null) ...[
                  Text('Requirement: ${widget.requirementId}'),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed:
                          _busy || !_sessionValid
                              ? null
                              : () => _run(_refreshList),
                      icon: const Icon(Icons.question_answer_outlined),
                      label: const LocalizedUiText('Load clarifications'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || !_sessionValid ? null : _loadSync,
                      icon: const Icon(Icons.sync),
                      label: const LocalizedUiText('Check Blueprint sync'),
                    ),
                  ],
                ),
                if (_sync != null) ...[
                  const Divider(height: 24),
                  Text(
                    _sync!['existingRequirementsSynchronized'] == true
                        ? 'Server reports requirements synchronized.'
                        : 'Server reports synchronization issues.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Blueprint revision: ${_sync!['blueprintRevision']}'),
                  for (final item in _sync!['items'] as List)
                    if (item is Map)
                      ListTile(
                        dense: true,
                        title: Text((item['requirementId'] ?? '').toString()),
                        subtitle: Text(
                          'Review: ${item['reviewStatus'] ?? 'Unknown'}'
                          ' | Blueprint: ${item['blueprintStatus'] ?? 'Missing'}'
                          '${item['problem'] == null ? '' : '\n${item['problem']}'}',
                        ),
                        trailing: Icon(
                          item['requiresRegeneration'] == true
                              ? Icons.warning_amber_outlined
                              : Icons.check_circle_outline,
                        ),
                      ),
                ],
                if (_loaded) ...[
                  const Divider(height: 24),
                  if (items.isEmpty)
                    const LocalizedUiText('No saved clarifications.'),
                  for (final item in items) ...[
                    Text(
                      (item['question'] ?? '').toString(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (widget.requirementId == null)
                      Text(
                        'Requirement: ${item['requirementId'] ?? 'Unknown'}',
                      ),
                    if (item['answer'] != null)
                      Text('Answer: ${item['answer']}')
                    else
                      const LocalizedUiText('Awaiting answer'),
                    if (item['answer'] == null && !widget.readOnly)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _canWrite ? () => _answer(item) : null,
                          child: const LocalizedUiText('Answer'),
                        ),
                      ),
                    const Divider(),
                  ],
                ],
                if (widget.requirementId != null &&
                    !widget.readOnly &&
                    !_writeBlocked) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('clarification-question'),
                    controller: _question,
                    enabled: _canWrite,
                    maxLength: 1500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: uiText(
                        context,
                        'New clarification question',
                        'புதிய விளக்கக் கேள்வி',
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  FilledButton(
                    onPressed:
                        !_canWrite || _question.text.trim().isEmpty
                            ? null
                            : _create,
                    child: const LocalizedUiText('Save clarification'),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_writeBlocked)
                  const Text(
                    'Close this dialog and reload the project before editing.',
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(liveRegion: true, child: Text(_notice!)),
                  ),
                const SizedBox(height: 12),
                const LocalizedUiText(
                  'Clarification answers do not automatically approve requirements.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const LocalizedUiText('Close'),
          ),
        ],
      ),
    );
  }
}
