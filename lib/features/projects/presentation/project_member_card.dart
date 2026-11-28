import 'package:flutter/material.dart';

import '../../../l10n/language_settings.dart';
import '../data/project_members_repository.dart';

class ProjectMemberCard extends StatelessWidget {
  const ProjectMemberCard({
    super.key,
    required this.member,
    required this.canManage,
    required this.busy,
    required this.onChangeRole,
    required this.onRemove,
  });

  final ProjectMember member;
  final bool canManage;
  final bool busy;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.role.apiValue,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SelectableText(member.userId),
            if (member.joinedAtUtc != null)
              Text(
                '${uiText(context, 'Joined', 'இணைந்தது')}: '
                '${member.joinedAtUtc!.toUtc().toIso8601String()}',
              ),
            if (canManage && !member.isOwner)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : onChangeRole,
                    child: Text(
                      member.role == ProjectMemberRole.editor
                          ? uiText(
                            context,
                            'Make Viewer',
                            'பார்வையாளராக மாற்று',
                          )
                          : uiText(
                            context,
                            'Make Editor',
                            'திருத்துபவராக மாற்று',
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : onRemove,
                    icon: const Icon(Icons.person_remove),
                    label: const LocalizedUiText('Remove'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
