import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import '../application/projects_providers.dart';
import '../data/project_members_repository.dart';
import 'project_invitation_widgets.dart';

final projectMembersRepositoryProvider = Provider<ProjectMembersRepository>((
  ref,
) {
  return ProjectMembersRepository(ref.watch(apiClientProvider));
});

// JWT claims are used for UI hints only.
// Backend authorization remains authoritative.
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

class ProjectMembersDialog extends StatefulWidget {
  const ProjectMembersDialog({
    super.key,
    required this.projectId,
    required this.actorId,
    required this.repository,
  });

  final String projectId;
  final String? actorId;
  final ProjectMembersRepository repository;

  @override
  State<ProjectMembersDialog> createState() => _ProjectMembersDialogState();
}

class _ProjectMembersDialogState extends State<ProjectMembersDialog> {
  final userId = TextEditingController();

  List<ProjectMember> members = [];
  ProjectMemberRole newRole = ProjectMemberRole.viewer;

  bool busy = true;
  bool loaded = false;
  String? error;
  String? notice;

  bool get canManage =>
      loaded &&
      widget.actorId != null &&
      members.any(
        (member) =>
            member.isOwner &&
            member.userId.toLowerCase() == widget.actorId!.toLowerCase(),
      );

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  @override
  void dispose() {
    userId.dispose();
    super.dispose();
  }

  String describeError(Object failure) {
    if (failure is ApiException) {
      return switch (failure.statusCode) {
        401 => 'Session expired. Sign in again.',
        403 => 'You do not have permission for this action.',
        404 => 'Project or registered user was not found.',
        409 => 'Membership conflict. Refresh and retry.',
        0 => 'Cannot reach the server. Refresh before retrying.',
        429 => 'Too many requests. Try again later.',
        _ => 'Membership request failed (HTTP ${failure.statusCode}).',
      };
    }

    return 'Membership data could not be processed. Refresh and try again.';
  }

  Future<void> loadMembers() async {
    setState(() {
      busy = true;
      loaded = false;
      error = null;
    });

    try {
      final result = await widget.repository.getMembers(widget.projectId);

      if (!mounted) return;

      setState(() {
        members = result;
        loaded = true;
      });
    } catch (failure) {
      if (!mounted) return;

      setState(() {
        members = [];
        error = describeError(failure);
      });
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> mutate(Future<void> Function() operation, String success) async {
    if (busy || !canManage) return;

    setState(() {
      busy = true;
      error = null;
      notice = null;
    });

    try {
      await operation();

      if (!mounted) return;

      setState(() => notice = success);
      await loadMembers();
    } catch (failure) {
      if (!mounted) return;

      setState(() {
        error = describeError(failure);
        loaded = false;
      });
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<bool> confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(message),
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
        ) ??
        false;
  }

  Future<void> openInvitation() async {
    if (busy || !canManage) return;

    await showDialog<void>(
      context: context,
      builder: (_) => const ProjectInvitationDialog(),
    );
  }

  Future<void> addMember() async {
    if (busy || !canManage) return;

    final id = userId.text.trim();

    if (!isProjectMemberGuid(id)) {
      setState(() => error = 'Enter a valid registered user ID.');
      return;
    }

    if (members.any(
      (member) => member.userId.toLowerCase() == id.toLowerCase(),
    )) {
      setState(() => error = 'This user is already a project member.');
      return;
    }

    final role = newRole;

    if (!await confirm(
      'Grant project access?',
      'Add $id as ${role.apiValue}?',
    )) {
      return;
    }

    if (!mounted) return;

    await mutate(() async {
      await widget.repository.setMemberRole(
        projectId: widget.projectId,
        memberUserId: id,
        role: role,
      );

      if (mounted) userId.clear();
    }, 'Project member added.');
  }

  Future<void> changeRole(ProjectMember member) async {
    if (busy || !canManage || member.isOwner) return;

    final role =
        member.role == ProjectMemberRole.editor
            ? ProjectMemberRole.viewer
            : ProjectMemberRole.editor;

    if (!await confirm(
      'Change member permissions?',
      'Change ${member.userId} to ${role.apiValue}?',
    )) {
      return;
    }

    if (!mounted) return;

    await mutate(() async {
      await widget.repository.setMemberRole(
        projectId: widget.projectId,
        memberUserId: member.userId,
        role: role,
      );
    }, 'Member role updated.');
  }

  Future<void> removeMember(ProjectMember member) async {
    if (busy || !canManage || member.isOwner) return;

    if (!await confirm(
      'Remove project member?',
      'Remove access for ${member.userId}?',
    )) {
      return;
    }

    if (!mounted) return;

    await mutate(() async {
      await widget.repository.removeMember(
        projectId: widget.projectId,
        memberUserId: member.userId,
      );
    }, 'Project member removed.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const LocalizedUiText('Project Members & Permissions'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Chip(label: LocalizedUiText('Owner')),
                  const Chip(label: LocalizedUiText('Editor')),
                  const Chip(label: LocalizedUiText('Viewer')),
                  OutlinedButton.icon(
                    onPressed: busy ? null : loadMembers,
                    icon: const Icon(Icons.refresh),
                    label: const LocalizedUiText('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (notice != null)
                Padding(padding: const EdgeInsets.all(8), child: Text(notice!)),
              if (loaded && !canManage)
                const Text(
                  'Read-only membership view. Only the project owner '
                  'can manage members.',
                ),
              if (loaded)
                for (final member in members)
                  Card(
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
                          if (canManage && !member.isOwner)
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed:
                                      busy ? null : () => changeRole(member),
                                  child: Text(
                                    member.role == ProjectMemberRole.editor
                                        ? 'Make Viewer'
                                        : 'Make Editor',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      busy ? null : () => removeMember(member),
                                  icon: const Icon(Icons.person_remove),
                                  label: const LocalizedUiText('Remove'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              if (canManage) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('open-project-invitation'),
                  onPressed: busy ? null : openInvitation,
                  icon: const Icon(Icons.mail_outline),
                  label: Text(
                    uiText(
                      context,
                      'Invite by Email',
                      '\u0bae\u0bbf\u0ba9\u0bcd\u0ba9\u0b9e\u0bcd\u0b9a\u0bb2\u0bcd \u0bae\u0bc2\u0bb2\u0bae\u0bcd \u0b85\u0bb4\u0bc8\u0b95\u0bcd\u0b95\u0bb5\u0bc1\u0bae\u0bcd',
                    ),
                  ),
                ),
                const Divider(height: 28),
                const Text(
                  'Add Registered Member',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('member-user-id'),
                  controller: userId,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: uiText(
                      context,
                      'Registered User ID',
                      'பதிவுசெய்த பயனரின் ID',
                    ),
                    hintText: 'Enter user GUID',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProjectMemberRole>(
                  initialValue: newRole,
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
                      DropdownMenuItem(value: role, child: Text(role.apiValue)),
                  ],
                  onChanged:
                      busy
                          ? null
                          : (role) {
                            if (role != null) {
                              setState(() => newRole = role);
                            }
                          },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('add-project-member'),
                  onPressed: busy ? null : addMember,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const LocalizedUiText('Add Member'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Adds an existing registered user directly. '
                  'Email invitations are not supported by this API.',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const LocalizedUiText('Close'),
        ),
      ],
    );
  }
}
