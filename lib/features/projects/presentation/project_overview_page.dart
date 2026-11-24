import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/projects_providers.dart';
import '../domain/project.dart';

class ProjectOverviewPage extends ConsumerWidget {
  const ProjectOverviewPage({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppShell(
    pageTitle: 'Project / Overview',
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

class _Contents extends StatelessWidget {
  const _Contents({required this.draft});
  final ProjectDraft draft;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageIntro(
        eyebrow: 'Project workspace',
        title: draft.name,
        subtitle:
            draft.description.isEmpty
                ? 'Your project is ready for the guided design process.'
                : draft.description,
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
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, size) {
          final tiles = <Widget>[
            FeatureTile(
              icon: Icons.file_upload_outlined,
              title: 'Input Studio',
              subtitle: 'Documents · Tamil/English voice · Text · Manual',
              label: 'Text and document input',
              onTap: () => context.go('/projects/${draft.projectId}/sources'),
            ),
            FeatureTile(
              icon: Icons.fact_check_outlined,
              title: 'Requirements Review',
              subtitle: 'Local-rule suggestions and human review',
              label: 'Local review available',
              onTap:
                  () => context.go('/projects/${draft.projectId}/review-input'),
            ),
            FeatureTile(
              icon: Icons.layers_outlined,
              title: '8-Step Builder',
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
              'Builder journey',
              subtitle: 'Your approved eight-stage workflow.',
              trailing: FilledButton.icon(
                onPressed:
                    () => context.go('/projects/${draft.projectId}/builder/1'),
                icon: const Icon(Icons.arrow_forward, size: 17),
                label: const Text('Continue'),
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
                'Project drafts, text input, document upload and local requirement review are implemented. Builder Steps 01-06 support draft editing, and Step 07 supports local simulated preview. Official AI, approval and export require Backend integration.',
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
