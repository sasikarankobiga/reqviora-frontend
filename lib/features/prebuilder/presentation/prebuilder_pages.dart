import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/language_settings.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../domain/review_summary.dart';
import 'ai_extraction_panel.dart';
import 'voice_input_panel.dart';
import '../../workspace/domain/draft_conflict.dart';

/// PB-05 Ã¢â‚¬â€ persisted text/manual source intake; file and voice services are
/// intentionally labeled unavailable, not falsely presented as functional.
class InputStudioPage extends ConsumerStatefulWidget {
  const InputStudioPage({super.key, required this.projectId});
  final String projectId;
  @override
  ConsumerState<InputStudioPage> createState() => _InputStudioPageState();
}

class _InputStudioPageState extends ConsumerState<InputStudioPage> {
  final label = TextEditingController(text: 'Project requirements');
  final input = TextEditingController();
  bool busy = false;
  String? error;
  bool conflict = false;

  void reportFailure(Object failure) {
    if (!mounted) return;
    setState(() {
      conflict = isDraftConflict(failure);
      error = draftConflictMessage(failure);
    });
  }

  @override
  void dispose() {
    label.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> saveText(Workspace w) async {
    if (input.text.trim().isEmpty) {
      setState(() => error = 'Describe your requirement first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      conflict = false;
    });
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .addText(w.projectId, w.version, input.text, label.text);
      input.clear();
      ref.invalidate(workspaceProvider(w.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text source saved with a source reference'),
          ),
        );
      }
    } catch (e) {
      reportFailure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> uploadFile(Workspace w) async {
    setState(() {
      busy = true;
      error = null;
      conflict = false;
    });
    try {
      final picked = await ref.read(sourcePickerProvider).pick();
      if (picked == null) return;
      final result = await ref
          .read(workspaceRepositoryProvider)
          .upload(w.projectId, w.version, picked.name, picked.bytes);
      ref.invalidate(workspaceProvider(w.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded ${result['fileName'] ?? picked.name} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      reportFailure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> suggest(Workspace w) async {
    setState(() {
      busy = true;
      error = null;
      conflict = false;
    });
    try {
      final result = await ref
          .read(workspaceRepositoryProvider)
          .analyze(w.projectId, w.version);
      ref.invalidate(workspaceProvider(w.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result['newSuggestions']} local-rule suggestions created Ã‚Â· user review required',
            ),
          ),
        );
      }
    } catch (e) {
      reportFailure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
    pageTitle: localizedLabel(context, 'Project / Input Studio'),
    projectId: widget.projectId,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          eyebrow: 'PB-05 Ã‚Â· Multi-input studio',
          title: localizedLabel(context, 'Turn ideas into clear requirements'),
          subtitle:
              'Capture evidence, then review every suggested requirement before confirmation.',
        ),
        const SizedBox(height: 19),
        LayoutBuilder(
          builder:
              (context, size) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in <(IconData, String, String, bool)>[
                    (
                      Icons.text_fields,
                      'Text input',
                      'Save typed source references',
                      true,
                    ),
                    (
                      Icons.tune_rounded,
                      'Manual',
                      'Enter features directly in Step 02',
                      true,
                    ),
                    (
                      Icons.file_upload_outlined,
                      'Documents',
                      'PDF, DOCX, TXT Ã‚Â· private upload',
                      true,
                    ),
                    (
                      Icons.mic_none_rounded,
                      'Voice',
                      'Tamil / English audio transcription',
                      true,
                    ),
                  ])
                    SizedBox(
                      width:
                          size.maxWidth >= 710
                              ? (size.maxWidth - 36) / 4
                              : size.maxWidth >= 440
                              ? (size.maxWidth - 12) / 2
                              : size.maxWidth,
                      child: FeatureTile(
                        icon: item.$1,
                        title: localizedLabel(context, item.$2),
                        subtitle: item.$3,
                        label: localizedLabel(
                          context,
                          item.$4 ? 'Available' : 'Not connected',
                        ),
                        active: item.$4,
                        onTap:
                            item.$2 == 'Manual'
                                ? () => context.go(
                                  '/projects/${widget.projectId}/builder/2',
                                )
                                : null,
                      ),
                    ),
                ],
              ),
        ),
        const SizedBox(height: 18),
        ref
            .watch(workspaceProvider(widget.projectId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => InlineError(
                    '$e',
                    onRetry:
                        () =>
                            ref.invalidate(workspaceProvider(widget.projectId)),
                  ),
              data:
                  (w) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(
                              localizedLabel(context, 'Add a text source'),
                              subtitle:
                                  'A stable source ID is saved with the current project version.',
                            ),
                            const SizedBox(height: 17),
                            TextField(
                              key: const ValueKey('source-title'),
                              controller: label,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: localizedLabel(
                                  context,
                                  'Source title',
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const ValueKey('source-content'),
                              controller: input,
                              minLines: 5,
                              maxLines: 9,
                              decoration: InputDecoration(
                                labelText: localizedLabel(
                                  context,
                                  'Requirement source content',
                                ),
                                hintText:
                                    'Example: Our coffee shop needs menu browsing, mock ordering and table booking.',
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 9,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy ? null : () => uploadFile(w),
                                  icon: const Icon(Icons.upload_file_outlined),
                                  label: Text(
                                    localizedLabel(
                                      context,
                                      'Upload PDF / DOCX / TXT',
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: busy ? null : () => saveText(w),
                                  icon: const Icon(Icons.save_outlined),
                                  label: Text(
                                    localizedLabel(context, 'Save source'),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : () => suggest(w),
                                  icon: const Icon(Icons.rule),
                                  label: Text(
                                    localizedLabel(
                                      context,
                                      'Suggest using local rules',
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      () => context.go(
                                        '/projects/${w.projectId}/review-input',
                                      ),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: Text(
                                    localizedLabel(
                                      context,
                                      'Review suggestions',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            const Text(
                              'TXT and DOCX text extraction is local. PDFs are stored with parser-pending status. Local rules are NOT remote AI.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: InlineError(
                                  error!,
                                  onRetry:
                                      conflict
                                          ? () {
                                            setState(() {
                                              conflict = false;
                                              error = null;
                                            });
                                            ref.invalidate(
                                              workspaceProvider(
                                                widget.projectId,
                                              ),
                                            );
                                          }
                                          : null,
                                ),
                              ),
                            ],
                            if (busy) const LinearProgressIndicator(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      VoiceInputPanel(
                        key: ValueKey('voice-${w.projectId}'),
                        workspace: w,
                        disabled: busy,
                      ),
                      const SizedBox(height: 15),
                      AiExtractionPanel(
                        key: ValueKey(w.projectId),
                        workspace: w,
                        disabled: busy,
                      ),
                      const SizedBox(height: 15),
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionTitle(
                              'Saved sources (${w.items('sources').length})',
                              subtitle:
                                  'Review source evidence before accepting extracted statements.',
                            ),
                            const SizedBox(height: 13),
                            if (w.items('sources').isEmpty)
                              Text(
                                localizedLabel(
                                  context,
                                  'No saved sources yet.',
                                ),
                                style: TextStyle(color: AppColors.muted),
                              ),
                            for (final s in w.items('sources'))
                              ListTile(
                                leading: const Icon(
                                  Icons.description_outlined,
                                  color: AppColors.purple,
                                ),
                                title: Text(
                                  (s['label'] ?? 'Source').toString(),
                                ),
                                subtitle: Text(
                                  (s['text'] ?? '').toString().isEmpty
                                      ? (s['note'] ?? 'No extracted text')
                                          .toString()
                                      : (s['text'] ?? '').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const SmallLabel('Text'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
      ],
    ),
  );
}

class InputReviewPage extends ConsumerStatefulWidget {
  const InputReviewPage({super.key, required this.projectId});
  final String projectId;
  @override
  ConsumerState<InputReviewPage> createState() => _InputReviewPageState();
}

class _InputReviewPageState extends ConsumerState<InputReviewPage> {
  String? error;
  bool conflict = false;
  String? pendingId;

  void reportFailure(Object failure) {
    if (!mounted) return;
    setState(() {
      conflict = isDraftConflict(failure);
      error = draftConflictMessage(failure);
    });
  }

  Future<void> decide(Workspace w, String id, String decision) async {
    setState(() {
      pendingId = id;
      error = null;
    });
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .decideCandidate(w.projectId, id, w.version, decision);
      ref.invalidate(workspaceProvider(w.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Suggestion $decision Ã‚Â· decision recorded'),
          ),
        );
      }
    } catch (e) {
      reportFailure(e);
    } finally {
      if (mounted) setState(() => pendingId = null);
    }
  }

  Future<void> editAndAccept(
    Workspace w,
    Map<String, dynamic> candidate,
  ) async {
    final name = TextEditingController(
      text: (candidate['name'] ?? '').toString(),
    );
    final description = TextEditingController(
      text: (candidate['description'] ?? '').toString(),
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: Text(localizedLabel(context, 'Edit & confirm suggestion')),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: localizedLabel(context, 'Requirement name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: localizedLabel(context, 'Description'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(localizedLabel(context, 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(localizedLabel(context, 'Confirm')),
              ),
            ],
          ),
    );
    if (accepted == true && name.text.trim().isNotEmpty) {
      setState(() {
        pendingId = candidate['id'].toString();
        error = null;
      });
      try {
        await ref
            .read(workspaceRepositoryProvider)
            .decideCandidate(
              w.projectId,
              candidate['id'].toString(),
              w.version,
              'accepted',
              editedName: name.text.trim(),
              editedDescription: description.text.trim(),
            );
        ref.invalidate(workspaceProvider(w.projectId));
      } catch (e) {
        reportFailure(e);
      } finally {
        if (mounted) setState(() => pendingId = null);
      }
    }
    name.dispose();
    description.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
    pageTitle: localizedLabel(context, 'Requirements Review'),
    projectId: widget.projectId,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          eyebrow: 'PB-06 Ã‚Â· Human confirmation',
          title: localizedLabel(context, 'You are in control'),
          subtitle:
              'Explicitly accept, reject or defer each proposed requirement.',
        ),
        const SizedBox(height: 18),
        ref
            .watch(workspaceProvider(widget.projectId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => InlineError(
                    '$e',
                    onRetry:
                        () =>
                            ref.invalidate(workspaceProvider(widget.projectId)),
                  ),
              data: (w) {
                final sources = {
                  for (final s in w.items('sources')) s['id']: s,
                };
                final candidates = w.items('candidates');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SurfaceCard(
                      color: Color(0xFFF3F0FF),
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.purple,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Only the project Owner may confirm suggested requirements under Strict Owner Control (AC-01D C1).',
                              style: TextStyle(fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final summary = ReviewSummary.fromCandidates(
                          candidates,
                        );

                        return SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Local requirement review summary',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SmallLabel('Suggested: ${summary.suggested}'),
                                  SmallLabel('Accepted: ${summary.accepted}'),
                                  SmallLabel('Rejected: ${summary.rejected}'),
                                  SmallLabel('Deferred: ${summary.deferred}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'These are local draft decisions, not Backend approval.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    if (candidates.isEmpty)
                      SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No suggestions yet. Manual Builder is always available.',
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed:
                                  () => context.go(
                                    '/projects/${w.projectId}/sources',
                                  ),
                              icon: const Icon(Icons.arrow_back),
                              label: Text(
                                localizedLabel(context, 'Open Input Studio'),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final c in candidates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (c['name'] ?? 'Candidate').toString(),
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                      ),
                                    ),
                                    SmallLabel(
                                      (c['status'] ?? 'suggested').toString(),
                                      color:
                                          c['status'] == 'accepted'
                                              ? AppColors.green
                                              : AppColors.purple,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                Text((c['description'] ?? '').toString()),
                                const SizedBox(height: 10),
                                Text(
                                  'Evidence: ${sources[c['sourceId']]?['label'] ?? 'Unlinked source'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (c['status'] == 'suggested')
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      FilledButton(
                                        onPressed:
                                            pendingId != null
                                                ? null
                                                : () => decide(
                                                  w,
                                                  c['id'].toString(),
                                                  'accepted',
                                                ),
                                        child: Text(
                                          localizedLabel(context, 'Accept'),
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed:
                                            pendingId != null
                                                ? null
                                                : () => editAndAccept(w, c),
                                        child: Text(
                                          localizedLabel(
                                            context,
                                            'Edit & Accept',
                                          ),
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed:
                                            pendingId != null
                                                ? null
                                                : () => decide(
                                                  w,
                                                  c['id'].toString(),
                                                  'rejected',
                                                ),
                                        child: Text(
                                          localizedLabel(context, 'Reject'),
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed:
                                            pendingId != null
                                                ? null
                                                : () => decide(
                                                  w,
                                                  c['id'].toString(),
                                                  'deferred',
                                                ),
                                        child: Text(
                                          localizedLabel(context, 'Defer'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                    if (error != null)
                      Semantics(
                        liveRegion: true,
                        child: InlineError(
                          error!,
                          onRetry:
                              conflict
                                  ? () {
                                    setState(() {
                                      conflict = false;
                                      error = null;
                                    });
                                    ref.invalidate(
                                      workspaceProvider(widget.projectId),
                                    );
                                  }
                                  : null,
                        ),
                      ),
                    const SizedBox(height: 13),
                    FilledButton.icon(
                      onPressed:
                          () =>
                              context.go('/projects/${w.projectId}/builder/1'),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        localizedLabel(context, 'Continue to Builder'),
                      ),
                    ),
                  ],
                );
              },
            ),
      ],
    ),
  );
}

class PendingPage extends StatelessWidget {
  const PendingPage({
    super.key,
    required this.title,
    required this.icon,
    this.projectId,
  });
  final String title;
  final IconData icon;
  final String? projectId;
  @override
  Widget build(BuildContext context) => AppShell(
    pageTitle: title,
    projectId: projectId,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageIntro(
          eyebrow: 'Not available in this local milestone',
          title: title,
          subtitle:
              'This approved V1 module is not yet wired to its secure service.',
        ),
        const SizedBox(height: 20),
        SurfaceCard(
          child: Column(
            children: [
              Icon(icon, size: 40, color: AppColors.purple),
              const SizedBox(height: 15),
              const Text('Not implemented Ã‚Â· No fake completed actions'),
              const SizedBox(height: 15),
              OutlinedButton(
                onPressed:
                    () => context.go(
                      projectId == null
                          ? '/projects'
                          : '/projects/$projectId/overview',
                    ),
                child: const Text('Back to workspace'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
