import '../../mcp_integration/presentation/widgets/mcp_handoff_dialog.dart';
import '../../mcp_integration/presentation/widgets/mcp_grants_button.dart';
import '../../billing/presentation/billing_button.dart';
import 'project_invitations_button.dart';
import 'project_members_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/language_settings.dart';
import '../application/projects_providers.dart';
import '../domain/project.dart';

class ProjectOverviewPage extends ConsumerWidget {
  const ProjectOverviewPage({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
    pageTitle: localizedLabel(context, 'Project / Overview'),
    projectId: projectId,
    child: ref
        .watch(projectDraftProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => InlineError(
                e.toString(),
                onRetry: () => ref.invalidate(projectDraftProvider(projectId)),
              ),
          data: (draft) => _Contents(draft: draft),
        ),
  );
}

class _Contents extends ConsumerWidget {
  const _Contents({required this.draft});
  final ProjectDraft draft;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final values = await showDialog<_ProjectEdit>(
      context: context,
      builder: (_) => _EditProjectDialog(draft: draft),
    );
    if (values == null || !context.mounted) return;

    try {
      await ref
          .read(projectsRepositoryProvider)
          .update(
            projectId: draft.projectId,
            name: values.name,
            description: values.description,
            category: values.category,
          );
      ref.invalidate(projectsProvider);
      ref.invalidate(projectDraftProvider(draft.projectId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'Project metadata updated by the backend.',
                'திட்ட விவரங்கள் பின்தளத்தால் புதுப்பிக்கப்பட்டன.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uiText(
                context,
                'Project update failed. Refresh and retry.',
                'திட்டப் புதுப்பிப்பு தோல்வியடைந்தது. புதுப்பித்து மீண்டும் முயலவும்.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageIntro(
        eyebrow: localizedLabel(context, 'Project workspace'),
        title: draft.name,
        subtitle:
            draft.description.isEmpty
                ? 'Your project is ready for the guided design process.'
                : draft.description,
        action: OutlinedButton.icon(
          key: const ValueKey('edit-project'),
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.edit_outlined),
          label: Text(uiText(context, 'Edit project', 'திட்டத்தைத் திருத்து')),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          const SmallLabel('DRAFT · EDITABLE'),
          SmallLabel('Version ${draft.version}', color: AppColors.blue),
          ...draft.targets.map(
            (t) => SmallLabel(t.toUpperCase(), color: AppColors.muted),
          ),
        ],
      ),
      const SizedBox(height: 20),
      ProjectMembersButton(projectId: draft.projectId),
      const SizedBox(height: 10),
      ProjectInvitationsButton(projectId: draft.projectId),
      const SizedBox(height: 10),
      McpHandoffButton(projectId: draft.projectId),
      const SizedBox(height: 10),
      McpGrantsButton(projectId: draft.projectId),
      const SizedBox(height: 10),
      ProjectBillingButton(projectId: draft.projectId),
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, size) {
          final tiles = <Widget>[
            FeatureTile(
              icon: Icons.file_upload_outlined,
              title: localizedLabel(context, 'Input Studio'),
              subtitle: 'Documents · Tamil/English voice · Text · Manual',
              label: 'Text and document input',
              onTap: () => context.go('/projects/${draft.projectId}/sources'),
            ),
            FeatureTile(
              icon: Icons.fact_check_outlined,
              title: localizedLabel(context, 'Requirements Review'),
              subtitle: 'Local-rule suggestions and human review',
              label: 'Local review available',
              onTap:
                  () => context.go('/projects/${draft.projectId}/review-input'),
            ),
            FeatureTile(
              icon: Icons.layers_outlined,
              title: localizedLabel(context, '8-Step Builder'),
              subtitle: 'Plan screens, design UI and review',
              label: 'Draft editor available',
              active: true,
              onTap: () => context.go('/projects/${draft.projectId}/builder/1'),
            ),
          ];
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children:
                tiles
                    .map(
                      (w) => SizedBox(
                        width:
                            size.maxWidth >= 870
                                ? (size.maxWidth - 28) / 3
                                : size.maxWidth >= 560
                                ? (size.maxWidth - 14) / 2
                                : size.maxWidth,
                        child: w,
                      ),
                    )
                    .toList(),
          );
        },
      ),
      const SizedBox(height: 26),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              localizedLabel(context, 'Builder journey'),
              subtitle: 'Your approved eight-stage workflow.',
              trailing: FilledButton.icon(
                onPressed:
                    () => context.go('/projects/${draft.projectId}/builder/1'),
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: Text(localizedLabel(context, 'Continue')),
              ),
            ),
            const SizedBox(height: 17),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(
                value: .125,
                minHeight: 8,
                backgroundColor: Color(0xFFEEEAFB),
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 9,
              children: [
                for (var i = 1; i <= 8; i++)
                  SmallLabel(
                    'Step $i',
                    color: i == 1 ? AppColors.purple : AppColors.muted,
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 17),
      const SurfaceCard(
        color: Color(0xFFFFFCF2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Color(0xFFB88225)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Project drafts, input intelligence, the eight-step Builder, validation, approval and official export use authenticated backend contracts. Provider-backed operations still require configured services.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.ink,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

typedef _ProjectEdit = ({String name, String description, String category});

class _EditProjectDialog extends StatefulWidget {
  const _EditProjectDialog({required this.draft});

  final ProjectDraft draft;

  @override
  State<_EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<_EditProjectDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.draft.name);
  late final description = TextEditingController(
    text: widget.draft.description,
  );
  late final category = TextEditingController(text: widget.draft.category);

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(uiText(context, 'Edit project', 'திட்டத்தைத் திருத்து')),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('edit-project-name'),
              controller: name,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: uiText(context, 'Project name', 'திட்டப் பெயர்'),
              ),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) < 2
                          ? uiText(
                            context,
                            'Enter at least 2 characters.',
                            'குறைந்தது 2 எழுத்துகளை உள்ளிடவும்.',
                          )
                          : null,
            ),
            TextFormField(
              controller: description,
              maxLength: 4000,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: uiText(context, 'Description', 'விளக்கம்'),
              ),
            ),
            TextFormField(
              controller: category,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: uiText(context, 'Category', 'வகை'),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(uiText(context, 'Cancel', 'ரத்து')),
      ),
      FilledButton(
        key: const ValueKey('save-project-edit'),
        onPressed: () {
          if (!(form.currentState?.validate() ?? false)) return;
          Navigator.pop<_ProjectEdit>(context, (
            name: name.text,
            description: description.text,
            category: category.text,
          ));
        },
        child: Text(uiText(context, 'Save', 'சேமி')),
      ),
    ],
  );
}
