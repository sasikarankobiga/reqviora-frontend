import 'package:flutter/material.dart';

import '../../../l10n/language_settings.dart';
import '../data/project_members_repository.dart';

typedef SendProjectInvitation =
    Future<void> Function(String email, ProjectMemberRole role);

typedef AcceptProjectInvitation = Future<void> Function();

bool isValidInvitationEmail(String value) {
  final email = value.trim();

  return email.length <= 320 &&
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
}

class ProjectInvitationDialog extends StatefulWidget {
  const ProjectInvitationDialog({super.key, this.onSend});

  final SendProjectInvitation? onSend;

  @override
  State<ProjectInvitationDialog> createState() =>
      _ProjectInvitationDialogState();
}

class _ProjectInvitationDialogState extends State<ProjectInvitationDialog> {
  final _email = TextEditingController();

  ProjectMemberRole _role = ProjectMemberRole.viewer;

  bool _busy = false;
  bool _sent = false;
  bool _invalid = false;
  bool _failed = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final send = widget.onSend;

    if (_busy || _sent || send == null) return;

    final email = _email.text.trim();

    if (!isValidInvitationEmail(email)) {
      setState(() => _invalid = true);
      return;
    }

    setState(() {
      _busy = true;
      _invalid = false;
      _failed = false;
    });

    try {
      await send(email, _role);

      if (!mounted) return;

      setState(() {
        _sent = true;
        _email.clear();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        uiText(context, 'Invite Project Member', 'திட்ட உறுப்பினரை அழைக்கவும்'),
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onSend == null)
                Text(
                  uiText(
                    context,
                    'Email invitation service is not configured.',
                    'மின்னஞ்சல் அழைப்புச் சேவை இணைக்கப்படவில்லை.',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('invitation-email'),
                controller: _email,
                enabled: !_busy && !_sent,
                keyboardType: TextInputType.emailAddress,
                maxLength: 320,
                decoration: InputDecoration(
                  labelText: uiText(
                    context,
                    'Email address',
                    'மின்னஞ்சல் முகவரி',
                  ),
                  errorText:
                      _invalid
                          ? uiText(
                            context,
                            'Enter a valid email address.',
                            'சரியான மின்னஞ்சல் முகவரியை உள்ளிடவும்.',
                          )
                          : null,
                ),
                onChanged: (_) {
                  if (_invalid) {
                    setState(() => _invalid = false);
                  }
                },
              ),
              DropdownButtonFormField<ProjectMemberRole>(
                key: const ValueKey('invitation-role'),
                initialValue: _role,
                decoration: InputDecoration(
                  labelText: uiText(
                    context,
                    'Project role',
                    'திட்டப் பொறுப்பு',
                  ),
                ),
                items: [
                  for (final role in [
                    ProjectMemberRole.viewer,
                    ProjectMemberRole.editor,
                  ])
                    DropdownMenuItem(
                      value: role,
                      child: Text(
                        role == ProjectMemberRole.viewer
                            ? uiText(context, 'Viewer', 'பார்வையாளர்')
                            : uiText(context, 'Editor', 'திருத்துபவர்'),
                      ),
                    ),
                ],
                onChanged:
                    _busy || _sent
                        ? null
                        : (role) {
                          if (role != null) {
                            setState(() => _role = role);
                          }
                        },
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_sent) ...[
                const SizedBox(height: 16),
                Text(
                  uiText(
                    context,
                    'Invitation sent.',
                    'அழைப்பு அனுப்பப்பட்டது.',
                  ),
                ),
              ],
              if (_failed) ...[
                const SizedBox(height: 16),
                Text(
                  uiText(
                    context,
                    'Invitation could not be sent. Check its status before retrying.',
                    'அழைப்பை அனுப்ப முடியவில்லை. மீண்டும் முயற்சிக்கும் முன் அதன் நிலையைச் சரிபார்க்கவும்.',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const LocalizedUiText('Close'),
        ),
        FilledButton(
          key: const ValueKey('send-project-invitation'),
          onPressed: _busy || _sent || widget.onSend == null ? null : _send,
          child: Text(uiText(context, 'Send Invitation', 'அழைப்பை அனுப்பவும்')),
        ),
      ],
    );
  }
}

class ProjectInvitationAcceptancePage extends StatefulWidget {
  const ProjectInvitationAcceptancePage({super.key, this.onAccept});

  final AcceptProjectInvitation? onAccept;

  @override
  State<ProjectInvitationAcceptancePage> createState() =>
      _ProjectInvitationAcceptancePageState();
}

class _ProjectInvitationAcceptancePageState
    extends State<ProjectInvitationAcceptancePage> {
  bool _busy = false;
  bool _accepted = false;
  bool _failed = false;

  Future<void> _accept() async {
    final accept = widget.onAccept;

    if (_busy || _accepted || accept == null) return;

    setState(() {
      _busy = true;
      _failed = false;
    });

    try {
      await accept();

      if (!mounted) return;

      setState(() => _accepted = true);
    } catch (_) {
      if (!mounted) return;

      setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(uiText(context, 'Project Invitation', 'திட்ட அழைப்பு')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_add_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      uiText(
                        context,
                        'Accept Project Invitation',
                        'திட்ட அழைப்பை ஏற்கவும்',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    if (widget.onAccept == null)
                      Text(
                        uiText(
                          context,
                          'Invitation acceptance service is not configured.',
                          'அழைப்பை ஏற்கும் சேவை இணைக்கப்படவில்லை.',
                        ),
                      ),
                    if (_busy) const LinearProgressIndicator(),
                    if (_accepted)
                      Text(
                        uiText(
                          context,
                          'Invitation accepted.',
                          'அழைப்பு ஏற்கப்பட்டது.',
                        ),
                      ),
                    if (_failed)
                      Text(
                        uiText(
                          context,
                          'Invitation could not be accepted. It may be invalid, expired, or unavailable.',
                          'அழைப்பை ஏற்க முடியவில்லை. அழைப்பு செல்லாததாகவோ காலாவதியானதாகவோ இருக்கலாம்.',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('accept-project-invitation'),
                      onPressed:
                          _busy || _accepted || widget.onAccept == null
                              ? null
                              : _accept,
                      child: Text(
                        uiText(
                          context,
                          'Accept Invitation',
                          'அழைப்பை ஏற்கவும்',
                        ),
                      ),
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
}
