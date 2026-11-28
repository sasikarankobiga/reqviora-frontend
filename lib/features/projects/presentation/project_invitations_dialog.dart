import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../data/project_invitations_repository.dart';
import '../data/project_members_repository.dart';
import '../domain/project_invitation.dart';
import 'project_invitation_tile.dart';
import 'project_invitation_widgets.dart';

class ProjectInvitationsDialog extends StatefulWidget {
  const ProjectInvitationsDialog({
    super.key,
    required this.projectId,
    required this.actorId,
    required this.members,
    required this.invitations,
  });

  final String projectId;
  final String? actorId;
  final ProjectMembersRepository members;
  final ProjectInvitationsRepository invitations;

  @override
  State<ProjectInvitationsDialog> createState() =>
      _ProjectInvitationsDialogState();
}

class _ProjectInvitationsDialogState extends State<ProjectInvitationsDialog> {
  var _items = const <ProjectInvitation>[];
  var _busy = true;
  var _owner = false;
  String? _error;
  int _operation = 0;
  late int _generation;

  @override
  void initState() {
    super.initState();
    _generation = authSession.generation;
    authSession.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) return;
    _generation = authSession.generation;
    setState(() {
      _operation++;
      _items = const [];
      _owner = false;
      _busy = false;
      _error = uiText(
        context,
        'Session changed. Close this dialog and try again.',
        'அமர்வு மாறியது. இந்த உரையாடலை மூடி மீண்டும் முயலவும்.',
      );
    });
  }

  String _message(Object failure) {
    if (failure is ApiException) {
      return switch (failure.statusCode) {
        401 => uiText(context, 'Sign in again.', 'மீண்டும் உள்நுழையவும்.'),
        403 => uiText(
          context,
          'Only the project owner can manage invitations.',
          'திட்ட உரிமையாளர் மட்டுமே அழைப்புகளை நிர்வகிக்க முடியும்.',
        ),
        409 => uiText(
          context,
          'Invitation state changed or a pending invitation already exists.',
          'அழைப்பு நிலை மாறியது அல்லது நிலுவை அழைப்பு ஏற்கனவே உள்ளது.',
        ),
        429 => uiText(
          context,
          'Too many invitation requests. Try again later.',
          'அதிக அழைப்பு கோரிக்கைகள். பின்னர் முயலவும்.',
        ),
        503 => uiText(
          context,
          'Invitation was stored, but email delivery is unavailable. Refresh before resending.',
          'அழைப்பு சேமிக்கப்பட்டது; மின்னஞ்சல் அனுப்பல் கிடைக்கவில்லை. மீண்டும் அனுப்பும் முன் புதுப்பிக்கவும்.',
        ),
        _ => uiText(
          context,
          'Invitation request failed.',
          'அழைப்பு கோரிக்கை தோல்வியடைந்தது.',
        ),
      };
    }
    return uiText(
      context,
      'Invitation data was invalid.',
      'அழைப்பு தரவு செல்லாது.',
    );
  }

  Future<void> _load() async {
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final members = await widget.members.getMembers(widget.projectId);
      final actor = widget.actorId?.toLowerCase();
      final owner = members.any(
        (item) => item.isOwner && item.userId.toLowerCase() == actor,
      );
      final items =
          owner
              ? await widget.invitations.list(widget.projectId)
              : const <ProjectInvitation>[];
      if (!mounted || operation != _operation) return;
      setState(() {
        _owner = owner;
        _items = items;
      });
    } catch (failure) {
      if (!mounted || operation != _operation) return;
      setState(() => _error = _message(failure));
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_owner) return;
    await showDialog<void>(
      context: context,
      builder:
          (_) => ProjectInvitationDialog(
            onSend: (email, role) async {
              await widget.invitations.create(
                projectId: widget.projectId,
                recipientEmail: email,
                role: role,
              );
            },
          ),
    );
    if (mounted) await _load();
  }

  Future<void> _mutate(ProjectInvitation item, bool resend) async {
    if (_busy || !_owner) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              resend
                  ? uiText(
                    context,
                    'Resend invitation?',
                    'அழைப்பை மீண்டும் அனுப்பவா?',
                  )
                  : uiText(
                    context,
                    'Revoke invitation?',
                    'அழைப்பை ரத்து செய்யவா?',
                  ),
            ),
            content: Text(item.recipientEmail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const LocalizedUiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const LocalizedUiText('Confirm'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (resend) {
        await widget.invitations.resend(
          projectId: widget.projectId,
          invitationId: item.id,
        );
      } else {
        await widget.invitations.revoke(
          projectId: widget.projectId,
          invitationId: item.id,
        );
      }
      if (mounted) await _load();
    } catch (failure) {
      if (mounted) setState(() => _error = _message(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, 'Email Invitations', 'மின்னஞ்சல் அழைப்புகள்')),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_busy && !_owner && _error == null)
              Text(
                uiText(
                  context,
                  'Only the project owner can manage invitations.',
                  'திட்ட உரிமையாளர் மட்டுமே அழைப்புகளை நிர்வகிக்க முடியும்.',
                ),
              ),
            if (_owner && _items.isEmpty && !_busy)
              Text(
                uiText(
                  context,
                  'No invitations yet.',
                  'இதுவரை அழைப்புகள் இல்லை.',
                ),
              ),
            for (final item in _items)
              ProjectInvitationTile(
                invitation: item,
                busy: _busy,
                onResend: () => _mutate(item, true),
                onRevoke: () => _mutate(item, false),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : _load,
        child: const LocalizedUiText('Refresh'),
      ),
      if (_owner)
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.person_add_alt),
          label: Text(uiText(context, 'Invite', 'அழைக்கவும்')),
        ),
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const LocalizedUiText('Close'),
      ),
    ],
  );
}
