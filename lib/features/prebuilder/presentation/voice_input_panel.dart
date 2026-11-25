import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../voice_processing/data/datasources/recorded_audio.dart';
import '../../voice_processing/data/datasources/browser_voice_recorder_stub.dart'
    if (dart.library.js_interop) '../../voice_processing/data/datasources/browser_voice_recorder.dart';
import 'package:reqviora_frontend/l10n/language_settings.dart';
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

  final recorder = BrowserVoiceRecorder();
  final recordingClock = Stopwatch();

  RecordedAudio? recordedAudio;
  Timer? recordingTimer;

  bool recording = false;
  bool requestingMicrophone = false;
  bool finishingRecording = false;
  int recordingGeneration = 0;
  int operationGeneration = 0;

  bool isCurrentOperation(int generation) =>
      mounted && generation == operationGeneration && !widget.disabled;
  int elapsedSeconds = 0;

  bool get blocked =>
      busy ||
      widget.disabled ||
      recording ||
      requestingMicrophone ||
      finishingRecording;

  bool get hasAudio => audio != null || recordedAudio != null;

  @override
  void dispose() {
    operationGeneration++;
    recordingGeneration++;
    recordingTimer?.cancel();
    recordingClock.stop();
    recorder.cancel();
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

  void resetTranscript() {
    transcript.clear();
    transcriptId = null;
    reviewed = false;
    consent = false;
    message = null;
  }

  @override
  void didUpdateWidget(covariant VoiceInputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if ((!oldWidget.disabled && widget.disabled) ||
        oldWidget.workspace.projectId != widget.workspace.projectId) {
      operationGeneration++;
      busy = false;
      error = null;
      recordingGeneration++;
      recordingTimer?.cancel();
      recordingClock.stop();
      recorder.cancel();

      recording = false;
      requestingMicrophone = false;
      finishingRecording = false;
      elapsedSeconds = 0;
      recordedAudio = null;
      audio = null;
      duration.clear();
      resetTranscript();
    }
  }

  Future<void> startRecording() async {
    if (blocked || !kIsWeb) return;

    final generation = ++recordingGeneration;

    setState(() {
      requestingMicrophone = true;
      error = null;
    });

    try {
      await recorder.start();

      if (!mounted || generation != recordingGeneration) return;

      if (widget.disabled) {
        recorder.cancel();
        return;
      }

      recordingClock
        ..reset()
        ..start();

      setState(() {
        recording = true;
        requestingMicrophone = false;
        elapsedSeconds = 0;
        recordedAudio = null;
        audio = null;
        duration.clear();
        resetTranscript();
      });

      recordingTimer?.cancel();

      recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !recording) return;

        final seconds = recordingClock.elapsed.inSeconds;

        setState(() {
          elapsedSeconds = seconds.clamp(0, 1800).toInt();
        });

        if (seconds >= 1800) {
          unawaited(stopRecording());
        }
      });
    } catch (failure) {
      if (mounted && generation == recordingGeneration) {
        recorder.cancel();

        setState(() {
          final permissionDenied = failure.toString().contains(
            'NotAllowedError',
          );

          error =
              permissionDenied
                  ? uiText(
                    context,
                    'Microphone permission denied. Allow microphone access in Windows and browser settings, or upload an audio file.',
                    'ஒலிவாங்கி அனுமதி மறுக்கப்பட்டுள்ளது. கணினி மற்றும் உலாவி அனுமதியைச் சரிபார்க்கவும் அல்லது ஒலிக் கோப்பைப் பதிவேற்றவும்.',
                  )
                  : uiText(
                    context,
                    'Microphone is unavailable. Retry or upload an audio file.',
                    'ஒலிவாங்கி கிடைக்கவில்லை. மீண்டும் முயற்சிக்கவும் அல்லது ஒலிக் கோப்பைப் பதிவேற்றவும்.',
                  );
        });
      }
    } finally {
      if (mounted && generation == recordingGeneration) {
        setState(() => requestingMicrophone = false);
      }
    }
  }

  Future<void> stopRecording() async {
    if (!recording || finishingRecording) return;

    final generation = recordingGeneration;

    recordingTimer?.cancel();
    recordingClock.stop();

    setState(() {
      recording = false;
      finishingRecording = true;
    });

    try {
      final result = await recorder.stop();

      if (!mounted || generation != recordingGeneration) return;

      setState(() {
        recordedAudio = result;
        audio = null;
        duration.text = result.durationSeconds.toString();
        elapsedSeconds = result.durationSeconds;
        resetTranscript();

        message = uiText(
          context,
          'Recording ready. Listen before submitting for transcription.',
          'ஒலிப்பதிவு தயாராக உள்ளது. உரையாக மாற்றுவதற்கு முன் கேளுங்கள்.',
        );
      });
    } catch (_) {
      if (mounted && generation == recordingGeneration) {
        recorder.cancel();

        setState(() {
          error = uiText(
            context,
            'Recording could not be completed. Please try again.',
            'ஒலிப்பதிவை முடிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          );
        });
      }
    } finally {
      if (mounted && generation == recordingGeneration) {
        setState(() => finishingRecording = false);
      }
    }
  }

  Future<void> playRecording() async {
    final selected = recordedAudio;

    if (blocked || selected == null) return;

    try {
      await recorder.play(selected.bytes);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = uiText(
            context,
            'Audio playback failed.',
            'ஒலியை இயக்க முடியவில்லை.',
          );
        });
      }
    }
  }

  void discardRecording() {
    if (busy || widget.disabled) return;

    recordingGeneration++;
    recordingTimer?.cancel();
    recordingClock.stop();
    recorder.cancel();

    setState(() {
      recording = false;
      requestingMicrophone = false;
      finishingRecording = false;
      elapsedSeconds = 0;
      recordedAudio = null;
      audio = null;
      duration.clear();
      error = null;
      resetTranscript();
    });
  }

  Future<void> selectAudio() async {
    if (blocked) return;

    final operation = ++operationGeneration;

    setState(() {
      busy = true;
      error = null;
    });

    try {
      final picked = await audio_picker.pickAudioFile();

      if (!isCurrentOperation(operation) || picked == null) return;

      setState(() {
        recorder.stopPlayback();
        recordedAudio = null;
        elapsedSeconds = 0;
        audio = picked;
        transcript.clear();
        duration.clear();
        transcriptId = null;
        reviewed = false;
        consent = false;
        message = null;
      });
    } catch (failure) {
      if (isCurrentOperation(operation)) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (isCurrentOperation(operation)) setState(() => busy = false);
    }
  }

  Future<void> transcribe() async {
    final selected = audio;
    final captured = recordedAudio;
    final filename = captured?.name ?? selected?.name;
    final bytes = captured?.bytes ?? selected?.bytes;

    if (blocked || filename == null || bytes == null || !consent) return;

    final seconds = int.tryParse(duration.text.trim());

    if (seconds == null || seconds < 1 || seconds > 1800) {
      setState(() => error = 'Enter the actual duration in seconds (1-1800).');
      return;
    }

    final operation = ++operationGeneration;

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
            filename: filename,
            bytes: bytes,
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

      if (!mounted || !isCurrentOperation(operation)) return;

      setState(() {
        transcriptId = id;
        transcript.text = text;
        message = 'Transcript received. Review and edit before saving.';
      });
    } catch (failure) {
      if (isCurrentOperation(operation)) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (isCurrentOperation(operation)) setState(() => busy = false);
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

    final operation = ++operationGeneration;

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

      if (!mounted || !isCurrentOperation(operation)) return;

      setState(() {
        recorder.stopPlayback();
        recordedAudio = null;
        elapsedSeconds = 0;
        audio = null;
        transcriptId = null;
        transcript.clear();
        duration.clear();
        reviewed = false;
        consent = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedUiText('Voice transcript saved as text source'),
        ),
      );

      ref.invalidate(workspaceProvider(projectId));
    } catch (failure) {
      if (isCurrentOperation(operation)) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (isCurrentOperation(operation)) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      uiText(context, 'Voice Intelligence', 'குரல் நுண்ணறிவு'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uiText(
                        context,
                        'Transform spoken ideas into reviewable project requirements.',
                        'பேசும் கருத்துகளை மீளாய்வு செய்யக்கூடிய திட்டத் தேவைகளாக மாற்றுங்கள்.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            uiText(context, 'Recording language', 'பதிவு மொழி'),
            style: Theme.of(context).textTheme.titleSmall,
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
            ],
          ),
          const SizedBox(height: 10),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor:
                        recording
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        recording
                            ? Theme.of(context).colorScheme.onError
                            : Theme.of(context).colorScheme.onPrimary,
                    child: Icon(
                      recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${(elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
                    '${(elapsedSeconds % 60).toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.disabled
                        ? uiText(
                          context,
                          'Read-only workspace',
                          'பார்வைக்கு மட்டும்',
                        )
                        : requestingMicrophone
                        ? uiText(
                          context,
                          'Requesting permission',
                          'அனுமதி கோரப்படுகிறது',
                        )
                        : finishingRecording
                        ? uiText(context, 'Preparing audio', 'ஒலி தயாராகிறது')
                        : recording
                        ? uiText(
                          context,
                          'Recording in progress',
                          'ஒலிப்பதிவு நடைபெறுகிறது',
                        )
                        : recordedAudio != null
                        ? uiText(context, 'Recording ready', 'ஒலிப்பதிவு தயார்')
                        : uiText(
                          context,
                          'Ready to record',
                          'பதிவு செய்யத் தயார்',
                        ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    uiText(
                      context,
                      'Speak your requirements. Maximum 30 minutes.',
                      'உங்கள் தேவைகளைப் பேசுங்கள். அதிகபட்சம் 30 நிமிடங்கள்.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: elapsedSeconds / 1800),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('voice-start-recording'),
                        onPressed: blocked ? null : startRecording,
                        icon: const Icon(Icons.mic),
                        label: Text(
                          uiText(context, 'Record audio', 'ஒலிப்பதிவு செய்க'),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('voice-stop-recording'),
                        onPressed:
                            recording && !finishingRecording
                                ? stopRecording
                                : null,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(
                          uiText(context, 'Stop recording', 'பதிவை நிறுத்துக'),
                        ),
                      ),
                      if (recordedAudio != null)
                        OutlinedButton.icon(
                          key: const ValueKey('voice-play-recording'),
                          onPressed: blocked ? null : playRecording,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            uiText(
                              context,
                              'Play recording',
                              'பதிவைக் கேளுங்கள்',
                            ),
                          ),
                        ),
                      if (recordedAudio != null)
                        OutlinedButton.icon(
                          onPressed: blocked ? null : recorder.stopPlayback,
                          icon: const Icon(Icons.stop),
                          label: Text(
                            uiText(context, 'Stop playback', 'ஒலியை நிறுத்துக'),
                          ),
                        ),
                      if (recording ||
                          requestingMicrophone ||
                          finishingRecording ||
                          recordedAudio != null)
                        OutlinedButton.icon(
                          key: const ValueKey('voice-discard-recording'),
                          onPressed:
                              busy || widget.disabled ? null : discardRecording,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(
                            uiText(
                              context,
                              'Discard / Record again',
                              'நீக்கு / மீண்டும் பதிவு செய்க',
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (requestingMicrophone)
                    Text(
                      uiText(
                        context,
                        'Waiting for microphone permission...',
                        'ஒலிவாங்கி அனுமதிக்காகக் காத்திருக்கிறது...',
                      ),
                    ),
                  if (recording)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '${uiText(context, 'Recording', 'பதிவாகிறது')} '
                        '${elapsedSeconds ~/ 60}:'
                        '${(elapsedSeconds % 60).toString().padLeft(2, '0')}',
                      ),
                    ),
                  if (finishingRecording) const LinearProgressIndicator(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              uiText(
                context,
                'Recording stays in this browser until you consent and select Transcribe audio.',
                'ஒப்புதல் அளித்து உரையாக மாற்றும் வரை ஒலிப்பதிவு இந்த உலாவியில் இருக்கும்.',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            recordedAudio?.name ??
                audio?.name ??
                uiText(
                  context,
                  'No audio selected',
                  'ஒலி தேர்ந்தெடுக்கப்படவில்லை',
                ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  uiText(
                    context,
                    'Upload an audio file',
                    'ஒலிக் கோப்பைப் பதிவேற்றுக',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'WAV, MP3, M4A, MP4, WebM - Max 25 MB',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: blocked ? null : selectAudio,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const LocalizedUiText('Select audio file'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: duration,
            enabled: !blocked && recordedAudio == null,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: uiText(
                context,
                'Actual audio duration in seconds',
                'ஒலியின் கால அளவு (வினாடிகள்)',
              ),
              hintText: 'Example: 60',
              prefixIcon: const Icon(Icons.timer_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            onChanged:
                blocked
                    ? null
                    : (value) => setState(() => consent = value ?? false),
            title: const LocalizedUiText(
              'I consent to server audio processing',
            ),
          ),
          FilledButton.icon(
            onPressed: blocked || !hasAudio || !consent ? null : transcribe,
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const LocalizedUiText('Transcribe audio'),
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
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              uiText(
                context,
                'Review your transcript',
                'குரல் உரையை மீளாய்வு செய்க',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: transcript,
              enabled: !blocked,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() => reviewed = false),
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  'Editable transcript',
                  'திருத்தக்கூடிய குரல் உரை',
                ),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: reviewed,
              onChanged:
                  blocked
                      ? null
                      : (value) => setState(() => reviewed = value ?? false),
              title: const LocalizedUiText('I have reviewed this transcript'),
            ),
            FilledButton.icon(
              onPressed: blocked || !reviewed ? null : saveTranscript,
              icon: const Icon(Icons.save_outlined),
              label: const LocalizedUiText('Save transcript as source'),
            ),
          ],
        ],
      ),
    );
  }
}
