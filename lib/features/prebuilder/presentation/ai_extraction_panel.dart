import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/domain/workspace.dart';

class AiExtractionPanel extends ConsumerStatefulWidget {
  const AiExtractionPanel({
    super.key,
    required this.workspace,
    this.disabled = false,
  });

  final Workspace workspace;
  final bool disabled;

  @override
  ConsumerState<AiExtractionPanel> createState() => _AiExtractionPanelState();
}

class _AiExtractionPanelState extends ConsumerState<AiExtractionPanel> {
  String language = 'en';
  bool consent = false;
  bool busy = false;
  String? error;
  String? message;

  List<Map<String, dynamic>> candidates = [];
  final Map<String, Map<String, dynamic>> serverReviews = {};

  List<Map<String, dynamic>> get sources =>
      widget.workspace.items('sources').where((source) {
        return (source['id'] ?? '').toString().isNotEmpty &&
            (source['text'] ?? '').toString().trim().isNotEmpty;
      }).toList();

  bool get blocked => busy || widget.disabled;

  String describeError(Object failure) {
    if (failure is ApiException) {
      if (failure.statusCode == 503) {
        return 'The AI provider is unavailable or awaiting approval.';
      }
      if (failure.statusCode == 403) {
        return 'You do not have permission for this operation.';
      }
      if (failure.statusCode == 409) {
        return 'The server reported a conflict. Refresh and review the current state.';
      }
      if (failure.statusCode == 401) {
        return 'Your session is unavailable. Please sign in again.';
      }
    }
    return failure.toString();
  }

  @override
  void initState() {
    super.initState();
    candidates = widget.workspace.items('aiCandidates');
  }

  Future<void> recoverReviews() async {
    if (blocked || candidates.isEmpty) return;

    for (final candidate in List.of(candidates)) {
      if (!mounted) return;
      await refreshReview(candidate['id'].toString());
    }
  }

  Future<void> extract() async {
    if (blocked || !consent || sources.isEmpty) {
      return;
    }

    final textParts = <String>[];
    final evidence = <Map<String, dynamic>>[];

    for (final source in sources) {
      final id = source['id'].toString();
      final text = source['text'].toString();

      textParts.add(text);
      evidence.add({
        'sourceId': id,
        'locator': 'text:0-${text.length}',
        'pageNumber': null,
        'startOffset': 0,
        'endOffset': text.length,
        'quote': text,
      });
    }

    final input = textParts.join('\n\n');

    if (input.length > 100000) {
      setState(() {
        error = 'Select or shorten sources to at most 100000 characters.';
      });
      return;
    }

    setState(() {
      busy = true;
      error = null;
      message = null;
    });

    try {
      final result = await ref
          .read(aiIntelligenceRepositoryProvider)
          .extractRequirements(
            projectId: widget.workspace.projectId,
            languageCode: language,
            inputText: input,
            evidence: evidence,
            consentGranted: consent,
          );

      if (!mounted) return;

      final repository = ref.read(workspaceRepositoryProvider);
      final latest = await repository.load(widget.workspace.projectId);

      if (!mounted) return;

      if (latest.version != widget.workspace.version) {
        throw StateError('Workspace changed. Reload and retry.');
      }

      final merged = <String, Map<String, dynamic>>{
        for (final item in latest.items('aiCandidates'))
          item['id'].toString(): item,
      };

      for (final item in result) {
        final id = item['id'];

        if (id is! String || id.isEmpty) {
          throw const FormatException('Invalid candidate ID');
        }

        merged.putIfAbsent(id, () => item);
      }

      await repository.save(
        latest.projectId,
        'aiCandidates',
        latest.version,
        merged.values.toList(),
      );

      if (!mounted) return;

      setState(() {
        candidates = merged.values.toList();
        message =
            '${result.length} AI suggestions received. Human review required.';
      });
      ref.invalidate(workspaceProvider(widget.workspace.projectId));
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> stage(Map<String, dynamic> candidate) async {
    if (blocked) return;

    final id = (candidate['id'] ?? '').toString();

    if (id.isEmpty) {
      setState(() => error = 'Candidate ID is missing.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
      message = null;
    });

    try {
      final repository = ref.read(aiIntelligenceRepositoryProvider);

      final review = await repository.stageCandidate(
        widget.workspace.projectId,
        candidate,
      );

      if (!mounted) return;

      setState(() {
        serverReviews[id] = review;
        message = 'Candidate staged on server. It is not yet confirmed.';
      });
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> refreshReview(String id) async {
    if (blocked || id.isEmpty) return;

    setState(() {
      busy = true;
      error = null;
      message = null;
    });

    try {
      final review = await ref
          .read(aiIntelligenceRepositoryProvider)
          .getReview(widget.workspace.projectId, id);

      if (!mounted) return;

      setState(() {
        serverReviews[id] = review;
        message = 'Server review status refreshed.';
      });
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> submitDecision(
    String id,
    String decision, {
    String? editedTitle,
    String? editedDescription,
  }) async {
    if (blocked) return;

    final current = serverReviews[id];
    final revision = current?['revision'];

    if (revision is! int || revision < 1) {
      setState(() => error = 'Refresh the server review before continuing.');
      return;
    }

    setState(() {
      busy = true;
      error = null;
      message = null;
    });

    try {
      final repository = ref.read(aiIntelligenceRepositoryProvider);

      final receipt = await repository.submitReview(
        projectId: widget.workspace.projectId,
        requirementId: id,
        expectedRevision: revision,
        decision: decision,
        editedTitle: editedTitle,
        editedDescription: editedDescription,
      );

      if (!mounted) return;

      setState(() {
        serverReviews[id] = {
          ...current!,
          'status': receipt['status'],
          'revision': receipt['revision'],
          if (decision == 'edit') 'title': editedTitle,
          if (decision == 'edit') 'description': editedDescription,
        };

        message =
            decision == 'edit'
                ? 'Edit saved. Explicitly accept the revised requirement.'
                : 'Server decision recorded: ${receipt['status']}';
      });
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> editReview(Map<String, dynamic> candidate) async {
    if (blocked) return;

    final id = candidate['id'].toString();
    final current = serverReviews[id];

    if (current == null) return;

    var title = (current['title'] ?? candidate['title'] ?? '').toString();
    var description =
        (current['description'] ?? candidate['description'] ?? '').toString();

    final edited = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit server requirement'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: title,
                      maxLength: 200,
                      onChanged: (value) => title = value,
                      decoration: const InputDecoration(
                        labelText: 'Requirement title',
                      ),
                    ),
                    TextFormField(
                      initialValue: description,
                      maxLength: 4000,
                      minLines: 3,
                      maxLines: 6,
                      onChanged: (value) => description = value,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const Text(
                      'Editing returns the requirement to Suggested. '
                      'A separate Accept decision is required.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save edit'),
              ),
            ],
          ),
    );

    if (!mounted || edited != true) return;

    if (title.trim().isEmpty) {
      setState(() => error = 'Requirement title is required.');
      return;
    }

    await submitDecision(
      id,
      'edit',
      editedTitle: title.trim(),
      editedDescription: description.trim(),
    );
  }

  Widget reviewControls(Map<String, dynamic> candidate) {
    final id = candidate['id'].toString();
    final review = serverReviews[id];

    if (review == null) return const SizedBox.shrink();

    final status = statusLabel(review['status']);

    final canDecide = status == 'Suggested' || status == 'Deferred';

    final canEdit = canDecide || status == 'Confirmed';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canDecide)
          FilledButton(
            onPressed: blocked ? null : () => submitDecision(id, 'accept'),
            child: const Text('Accept requirement'),
          ),
        if (canEdit)
          OutlinedButton(
            onPressed: blocked ? null : () => editReview(candidate),
            child: const Text('Edit requirement'),
          ),
        if (canDecide)
          OutlinedButton(
            onPressed: blocked ? null : () => submitDecision(id, 'reject'),
            child: const Text('Reject requirement'),
          ),
        if (status == 'Suggested')
          OutlinedButton(
            onPressed: blocked ? null : () => submitDecision(id, 'defer'),
            child: const Text('Defer requirement'),
          ),
      ],
    );
  }

  String statusLabel(dynamic status) {
    return switch (status?.toString().toLowerCase()) {
      '0' || 'suggested' => 'Suggested',
      '1' || 'confirmed' => 'Confirmed',
      '2' || 'rejected' => 'Rejected',
      '3' || 'deferred' => 'Deferred',
      _ => 'Unknown',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'AI Requirements Extraction',
            subtitle:
                'Extract suggestions from saved sources using the server AI provider.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: language == 'en',
                onSelected:
                    blocked ? null : (_) => setState(() => language = 'en'),
              ),
              ChoiceChip(
                label: const Text('Tamil'),
                selected: language == 'ta',
                onSelected:
                    blocked ? null : (_) => setState(() => language = 'ta'),
              ),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: consent,
            onChanged:
                blocked
                    ? null
                    : (value) => setState(() => consent = value ?? false),
            title: const Text('I consent to AI processing of saved sources'),
            subtitle: const Text(
              'Selected project source text is sent to the configured server AI service.',
            ),
          ),
          Text('${sources.length} text sources available'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: blocked || !consent || sources.isEmpty ? null : extract,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Extract with AI'),
          ),
          OutlinedButton.icon(
            onPressed: blocked || candidates.isEmpty ? null : recoverReviews,
            icon: const Icon(Icons.refresh),
            label: const Text('Recover saved server reviews'),
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: InlineError(error!)),
          ],
          if (message != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(message!)),
          ],
          for (final candidate in candidates) ...[
            const Divider(height: 24),
            Text(
              (serverReviews[candidate['id'].toString()]?['title'] ??
                      candidate['title'] ??
                      'Requirement')
                  .toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              (serverReviews[candidate['id'].toString()]?['description'] ??
                      candidate['description'] ??
                      '')
                  .toString(),
            ),
            const SizedBox(height: 6),
            Text('AI confidence: ${candidate['confidence'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            reviewControls(candidate),
            if (candidate['evidence'] is List)
              for (final item in candidate['evidence'] as List)
                if (item is Map)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Evidence: ${item['sourceId']} - ${item['quote']}',
                    ),
                  ),
            const SizedBox(height: 8),
            Text(
              serverReviews.containsKey(candidate['id'].toString())
                  ? 'Server status: ${statusLabel(serverReviews[candidate['id'].toString()]?['status'])}'
                  : 'Not staged on server',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed:
                      blocked ||
                              serverReviews.containsKey(
                                candidate['id'].toString(),
                              )
                          ? null
                          : () => stage(candidate),
                  child: const Text('Stage for review'),
                ),
                OutlinedButton(
                  onPressed:
                      blocked
                          ? null
                          : () => refreshReview(candidate['id'].toString()),
                  child: const Text('Refresh server status'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
