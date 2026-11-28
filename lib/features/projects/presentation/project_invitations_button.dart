import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../l10n/language_settings.dart';
import '../application/project_invitations_provider.dart';
import 'project_invitations_dialog.dart';
import 'project_members_access.dart';

class ProjectInvitationsButton extends ConsumerWidget {
  const ProjectInvitationsButton({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const ValueKey('open-project-invitations'),
      icon: const Icon(Icons.mail_outline),
      label: Text(
        uiText(context, 'Email Invitations', 'மின்னஞ்சல் அழைப்புகள்'),
      ),
      onPressed:
          () => showDialog<void>(
            context: context,
            builder:
                (_) => ProjectInvitationsDialog(
                  projectId: projectId,
                  actorId: projectMemberActorId(authSession.token),
                  members: ref.read(projectMembersRepositoryProvider),
                  invitations: ref.read(projectInvitationsRepositoryProvider),
                ),
          ),
    );
  }
}
