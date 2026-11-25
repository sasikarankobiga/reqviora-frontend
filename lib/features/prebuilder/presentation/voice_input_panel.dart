import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../projects/application/projects_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/domain/source_picker.dart';
import '../../workspace/data/browser_audio_picker_stub.dart'
    if (dart.library.html) '../../workspace/data/browser_audio_picker.dart'
    as audio_picker;

class VoiceInputPanel extends ConsumerStatefulWidget {
  const VoiceInputPanel({
    super.key,
    required this.workspace,
    this.disabled = false,
  });

  final Workspace workspace;
  final bool disabled;

  @override
  ConsumerState<VoiceInputPanel> createState() => _VoiceInputPanelState();
}

class _VoiceInputPanelState extends ConsumerState<VoiceInputPanel> {
  final duration = TextEditingController();
  final transcript = TextEditingController();

  String language = 'en';
  SourceFile? audio;
  bool consent = false;
  bool reviewed = false;
  bool busy = false;
  String? error;
  String? message;
  String? transcriptId;

  bool get blocked => busy || widget.disabled;

  @override
  void dispose() {
    duration.dispose();
    transcript.dispose();
    super.dispose();
  }

  String describeError(Object failure) {
    if (failure is ApiException && failure.statusCode == 503) {
      return 'Voice provider is unavailable or awaiting approval.';
    }

    if (failure is ApiException && failure.statusCode == 409) {
      return 'Workspace changed. Reload before saving.';
    }

    return failure.toString();
  }

  Future<void> selectAudio() async {
    if (blocked) return;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final picked = await audio_picker.pickAudioFile();

      if (!mounted || picked == null) return;

      setState(() {
        audio = picked;
        transcript.clear();
        duration.clear();
        transcriptId = null;
        reviewed = false;
        consent = false;
        message = null;
      });
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> transcribe() async {
    final selected = audio;

    if (blocked || selected == null || !consent) return;

    final seconds = int.tryParse(duration.text.trim());

    if (seconds == null || seconds < 1 || seconds > 1800) {
      setState(() => error = 'Enter the actual duration in seconds (1-1800).');
      return;
    }

    setState(() {
      busy = true;
      error = null;
      message = null;
      reviewed = false;
      transcriptId = null;
      transcript.clear();
    });

    try {
      final result = await ref
          .read(apiClientProvider)
          .transcribeAudio(
            projectId: widget.workspace.projectId,
            filename: selected.name,
            bytes: selected.bytes,
            languageCode: language,
            durationSeconds: seconds,
            consentGranted: consent,
          );

      final id = result['transcriptId'];
      final text = result['editableText'];

      if (id is! String ||
          id.isEmpty ||
          text is! String ||
          text.trim().isEmpty) {
        throw const FormatException('Incomplete server transcript');
      }

      if (!mounted) return;

      setState(() {
        transcriptId = id;
        transcript.text = text;
        message = 'Transcript received. Review and edit before saving.';
      });
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveTranscript() async {
    if (blocked ||
        !reviewed ||
        transcriptId == null ||
        transcript.text.trim().isEmpty) {
      return;
    }

    final projectId = widget.workspace.projectId;

    setState(() {
      busy = true;
      error = null;
      message = null;
    });

    try {
      await ref
          .read(workspaceRepositoryProvider)
          .addText(
            projectId,
            widget.workspace.version,
            transcript.text,
            'Reviewed voice transcript - $transcriptId',
          );

      if (!mounted) return;

      setState(() {
        audio = null;
        transcriptId = null;
        transcript.clear();
        duration.clear();
        reviewed = false;
        consent = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice transcript saved as text source')),
      );

      ref.invalidate(workspaceProvider(projectId));
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Voice Input',
            subtitle: 'Upload recorded audio and review the server transcript.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('English'),
                selected: language == 'en',
                onSelected:
                    blocked
                        ? null
                        : (_) => setState(() {
                          language = 'en';
                          consent = false;
                          reviewed = false;
                          transcriptId = null;
                          transcript.clear();
                        }),
              ),
              ChoiceChip(
                label: const Text('Tamil'),
                selected: language == 'ta',
                onSelected:
                    blocked
                        ? null
                        : (_) => setState(() {
                          language = 'ta';
                          consent = false;
                          reviewed = false;
                          transcriptId = null;
                          transcript.clear();
                        }),
              ),
              OutlinedButton.icon(
                onPressed: blocked ? null : selectAudio,
                icon: const Icon(Icons.audio_file_outlined),
                label: const Text('Select audio file'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(audio?.name ?? 'No audio selected'),
          const Text('WAV, MP3, M4A, MP4 or WebM. Maximum 25 MB.'),
          const SizedBox(height: 12),
          TextField(
            controller: duration,
            enabled: !blocked,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Actual audio duration in seconds',
              hintText: 'Example: 60',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            onChanged:
                blocked
                    ? null
                    : (value) => setState(() => consent = value ?? false),
            title: const Text('I consent to server audio processing'),
          ),
          FilledButton.icon(
            onPressed: blocked || audio == null || !consent ? null : transcribe,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('Transcribe audio'),
          ),
          if (busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Semantics(liveRegion: true, child: InlineError(error!)),
          ],
          if (message != null) ...[const SizedBox(height: 10), Text(message!)],
          if (transcriptId != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: transcript,
              enabled: !blocked,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() => reviewed = false),
              decoration: const InputDecoration(
                labelText: 'Editable transcript',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: reviewed,
              onChanged:
                  blocked
                      ? null
                      : (value) => setState(() => reviewed = value ?? false),
              title: const Text('I have reviewed this transcript'),
            ),
            FilledButton.icon(
              onPressed: blocked || !reviewed ? null : saveTranscript,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save transcript as source'),
            ),
          ],
        ],
      ),
    );
  }
}
