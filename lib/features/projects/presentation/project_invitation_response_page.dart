import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../application/project_invitations_provider.dart';
import '../application/projects_providers.dart';

class PendingInvitationResponse {
  String? _token;

  void capture(String token) {
    if (token.trim() == token && token.length >= 32 && token.length <= 512) {
      _token = token;
    }
  }

  String? take() {
    final token = _token;
    _token = null;
    return token;
  }
}

final pendingInvitationResponse = PendingInvitationResponse();

class ProjectInvitationResponsePage extends ConsumerStatefulWidget {
  const ProjectInvitationResponsePage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ProjectInvitationResponsePage> createState() =>
      _ProjectInvitationResponsePageState();
}

class _ProjectInvitationResponsePageState
    extends ConsumerState<ProjectInvitationResponsePage> {
  bool _busy = false;
  String? _error;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(projectInvitationsRepositoryProvider);
      final projectId =
          accept
              ? (await repository.accept(widget.token)).projectId
              : (await repository.reject(widget.token)).projectId;
      if (mounted) {
        if (accept) ref.invalidate(projectsProvider);
        context.go('/projects/$projectId/overview');
      }
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _error =
            failure is ApiException && failure.statusCode == 409
                ? uiText(
                  context,
                  'This invitation is expired or has already been used.',
                  'இந்த அழைப்பு காலாவதியானது அல்லது ஏற்கனவே பயன்படுத்தப்பட்டது.',
                )
                : uiText(
                  context,
                  'The invitation could not be updated.',
                  'அழைப்பை புதுப்பிக்க முடியவில்லை.',
                );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(uiText(context, 'Project Invitation', 'திட்ட அழைப்பு')),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    uiText(
                      context,
                      'Respond to Project Invitation',
                      'திட்ட அழைப்பிற்கு பதிலளிக்கவும்',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    uiText(
                      context,
                      'Accept to join the project, or reject to close this invitation.',
                      'திட்டத்தில் சேர ஏற்கவும் அல்லது அழைப்பை முடிக்க நிராகரிக்கவும்.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : () => _respond(false),
                        child: Text(uiText(context, 'Reject', 'நிராகரி')),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : () => _respond(true),
                        child: Text(uiText(context, 'Accept', 'ஏற்கவும்')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
