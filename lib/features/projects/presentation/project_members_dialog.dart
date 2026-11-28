import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../data/project_members_repository.dart';
import 'project_member_card.dart';

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
  List<ProjectMember> members = [];

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
                  ProjectMemberCard(
                    member: member,
                    canManage: canManage,
                    busy: busy,
                    onChangeRole: () => changeRole(member),
                    onRemove: () => removeMember(member),
                  ),
              if (canManage) ...[
                const SizedBox(height: 12),
                Text(
                  uiText(
                    context,
                    'New members must accept an email invitation before '
                        'their roles can be managed here.',
                    'புதிய உறுப்பினர்கள் இங்கு தங்கள் பொறுப்புகளை நிர்வகிக்கும் '
                        'முன் மின்னஞ்சல் அழைப்பை ஏற்க வேண்டும்.',
                  ),
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
