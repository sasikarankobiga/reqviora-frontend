import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../l10n/language_settings.dart';
import '../application/projects_providers.dart';
import '../data/project_members_repository.dart';
import 'project_members_dialog.dart';

final projectMembersRepositoryProvider = Provider<ProjectMembersRepository>((
  ref,
) {
  return ProjectMembersRepository(ref.watch(apiClientProvider));
});

// JWT claims are used for UI hints only. Backend authorization is authoritative.
String? projectMemberActorId(String? token) {
  if (token == null) return null;

  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;

    final candidates =
        [
              payload['sub'],
              payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier'],
              payload['nameid'],
            ]
            .whereType<String>()
            .where(isProjectMemberGuid)
            .map((id) => id.toLowerCase())
            .toSet();
    return candidates.length == 1 ? candidates.single : null;
  } catch (_) {
    return null;
  }
}

class ProjectMembersButton extends ConsumerWidget {
  const ProjectMembersButton({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const ValueKey('open-project-members'),
      icon: const Icon(Icons.group_outlined),
      label: const LocalizedUiText('Project Members & Permissions'),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder:
              (_) => ProjectMembersDialog(
                projectId: projectId,
                actorId: projectMemberActorId(authSession.token),
                repository: ref.read(projectMembersRepositoryProvider),
              ),
        );
      },
    );
  }
}
