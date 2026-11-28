import 'package:flutter/material.dart';

import '../../../l10n/language_settings.dart';
import '../data/project_members_repository.dart';
import '../domain/project_invitation.dart';

class ProjectInvitationTile extends StatelessWidget {
  const ProjectInvitationTile({
    super.key,
    required this.invitation,
    required this.busy,
    required this.onResend,
    required this.onRevoke,
  });

  final ProjectInvitation invitation;
  final bool busy;
  final VoidCallback onResend;
  final VoidCallback onRevoke;

  String _status(BuildContext context) => switch (invitation.status) {
    ProjectInvitationStatus.pending => uiText(context, 'Pending', 'நிலுவையில்'),
    ProjectInvitationStatus.accepted => uiText(
      context,
      'Accepted',
      'ஏற்கப்பட்டது',
    ),
    ProjectInvitationStatus.rejected => uiText(
      context,
      'Rejected',
      'நிராகரிக்கப்பட்டது',
    ),
    ProjectInvitationStatus.revoked => uiText(
      context,
      'Revoked',
      'ரத்து செய்யப்பட்டது',
    ),
    ProjectInvitationStatus.expired => uiText(
      context,
      'Expired',
      'காலாவதியானது',
    ),
  };

  String _role(BuildContext context) =>
      invitation.role == ProjectMemberRole.editor
          ? uiText(context, 'Editor', 'திருத்துபவர்')
          : uiText(context, 'Viewer', 'பார்வையாளர்');

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(invitation.recipientEmail),
      subtitle: Text(
        '${_role(context)} · ${_status(context)} · '
        '${invitation.expiresAt.toLocal()}',
      ),
      trailing:
          invitation.canResend
              ? Wrap(
                children: [
                  IconButton(
                    onPressed: busy ? null : onResend,
                    icon: const Icon(Icons.refresh),
                    tooltip: uiText(context, 'Resend', 'மீண்டும் அனுப்பு'),
                  ),
                  IconButton(
                    onPressed: busy ? null : onRevoke,
                    icon: const Icon(Icons.cancel_outlined),
                    tooltip: uiText(context, 'Revoke', 'ரத்து செய்'),
                  ),
                ],
              )
              : null,
    ),
  );
}
