import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/constants/builder_stages.dart';
import '../../projects/application/projects_providers.dart';
import '../../projects/domain/project.dart';
import '../../workspace/presentation/authoring_page.dart';

class BuilderPage extends ConsumerWidget {
  const BuilderPage({super.key, required this.projectId, required this.step});
  final String projectId;
  final int step;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final number = step.clamp(1, 8);
    return AppShell(pageTitle: 'Builder / Step $number', projectId: projectId,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PageIntro(eyebrow: '8-Step Builder · Step $number of 8', title: builderStageNames[number - 1],
          subtitle: builderStageDescriptions[number - 1]),
        const SizedBox(height: 20), _StageBar(projectId: projectId, selected: number),
        const SizedBox(height: 22),
        if (number == 1) ref.watch(projectDraftProvider(projectId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => InlineError(e.toString(),
            onRetry: () => ref.invalidate(projectDraftProvider(projectId))),
          data: (draft) => IdentityEditor(key: ValueKey('$projectId-${draft.version}'),
            draft: draft),
        ) else BuilderAuthoringPage(projectId: projectId, step: number),
      ]));
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.projectId, required this.selected});
  final String projectId;
  final int selected;
  @override Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(15), child: Column(children: [
      Row(children: [Expanded(child: Text('Your workflow',
        style: Theme.of(context).textTheme.titleMedium)),
        SmallLabel('$selected / 8'),
      ]), const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(7), child: LinearProgressIndicator(
        value: selected / 8, minHeight: 6, backgroundColor: const Color(0xFFEFEAFC),
        color: AppColors.purple)),
      const SizedBox(height: 13), SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [for (var i = 1; i <= 8; i++) Padding(
          padding: const EdgeInsets.only(right: 7), child: ActionChip(
            avatar: CircleAvatar(radius: 12, backgroundColor:
              i == selected ? AppColors.purple : const Color(0xFFEFEDFA),
              child: Text('$i', style: TextStyle(fontSize: 11,
                color: i == selected ? Colors.white : AppColors.muted))),
            label: Text(builderStageNames[i - 1], style: TextStyle(
              fontSize: 11, color: i == selected ? AppColors.purple : AppColors.ink,
              fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500)),
            onPressed: () => context.go('/projects/$projectId/builder/$i'),
            backgroundColor: i == selected ? const Color(0xFFF0EAFF) : Colors.white,
            side: const BorderSide(color: AppColors.line),
          ))])),
    ]));
}

class IdentityEditor extends ConsumerStatefulWidget {
  const IdentityEditor({super.key, required this.draft});
  final ProjectDraft draft;
  @override ConsumerState<IdentityEditor> createState() => _IdentityEditorState();
}
class _IdentityEditorState extends ConsumerState<IdentityEditor> {
  final keyForm = GlobalKey<FormState>();
  late final Map<String, TextEditingController> inputs;
  late Set<String> targets;
  bool saving = false;
  String? error;
  String? notice;
  static const fields = <String, String>{
    'name': 'Project Name *',
    'description': 'Project Description',
    'category': 'Project Category / Industry',
    'tagline': 'Project Tagline',
    'problemStatement': 'Problem Statement',
    'goals': 'Project Goals & Objectives',
    'targetAudience': 'Target Audience',
    'personas': 'User Personas',
    'applicationRoles': 'User Roles & Responsibilities',
    'inScope': 'In Scope',
    'outOfScope': 'Out of Scope',
    'constraints': 'Business Constraints & Assumptions',
    'successCriteria': 'Project Success Criteria',
  };
  @override void initState() {
    super.initState();
    inputs = {
      for (final entry in fields.entries)
        entry.key: TextEditingController(text: switch (entry.key) {
          'name' => widget.draft.name,
          'description' => widget.draft.description,
          'category' => widget.draft.category,
          _ => widget.draft.field(entry.key),
        }),
    };
    targets = widget.draft.targets.toSet();
  }
  @override void dispose() {
    for (final v in inputs.values) { v.dispose(); }
    super.dispose();
  }
  Future<void> save({bool proceed = false}) async {
    if (!(keyForm.currentState?.validate() ?? false)) return;
    setState(() { saving = true; error = null; notice = null; });
    try {
      final values = <String, dynamic>{'expectedVersion': widget.draft.version,
        'designTargets': targets.toList(),
        for (final e in inputs.entries) e.key: e.value.text.trim()};
      final fresh = await ref.read(projectsRepositoryProvider).saveIdentity(widget.draft.projectId, values);
      ref.invalidate(projectDraftProvider(widget.draft.projectId));
      ref.invalidate(projectsProvider);
      if (mounted) {
        if (proceed) {
          context.go('/projects/${widget.draft.projectId}/builder/2');
        } else {
          setState(() => notice = 'Draft saved successfully · version ${fresh.version}');
        }
      }
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }
  Widget input(String key, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fields[key]!, style: const TextStyle(color: AppColors.ink,
          fontWeight: FontWeight.w800, fontSize: 12)),
        const SizedBox(height: 7), TextFormField(controller: inputs[key], maxLines: lines,
          decoration: InputDecoration(hintText: 'Enter ${fields[key]!.replaceAll('*', '').toLowerCase()}'),
          validator: key == 'name' ? (s) => s == null || s.trim().isEmpty
            ? 'Project name is required' : null : null),
      ]));
  @override Widget build(BuildContext context) => Form(key: keyForm,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SurfaceCard(color: Color(0xFFF2F0FF), padding: EdgeInsets.all(17),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.auto_awesome_outlined, color: AppColors.purple), SizedBox(width: 12),
          Expanded(child: Text('Prefilled from Create Project. You can edit and save this information. AI suggestions need separate Owner confirmation before becoming authoritative.',
            style: TextStyle(fontSize: 12, height: 1.5))),
        ])), const SizedBox(height: 17),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Project identity', subtitle: 'Name, purpose, category and target platform.'),
        const SizedBox(height: 21),
        input('name'), input('tagline'), input('description', lines: 3), input('category'),
        const Text('Design Target · Web / Mobile / Desktop', style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7), Wrap(spacing: 8, children: ['web', 'mobile', 'desktop'].map((t) =>
          FilterChip(label: Text(t.toUpperCase()), selected: targets.contains(t),
            onSelected: (v) => setState(() {
              if (v) { targets.add(t); } else if (targets.length > 1) { targets.remove(t); }
            }))).toList()),
      ])), const SizedBox(height: 16),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Purpose & audience', subtitle: 'Describe problems and intended users.'),
        const SizedBox(height: 21), input('problemStatement', lines: 3),
        input('goals', lines: 3), input('targetAudience', lines: 3),
        input('personas', lines: 2), input('applicationRoles', lines: 2),
      ])), const SizedBox(height: 16),
      SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Scope & success', subtitle: 'Keep project boundaries and outcomes clear.'),
        const SizedBox(height: 21), input('inScope', lines: 2),
        input('outOfScope', lines: 2), input('constraints', lines: 2),
        input('successCriteria', lines: 2),
        const SmallLabel('Source references & AI suggestions: future service integration',
          color: AppColors.muted),
      ])),
      if (error != null) ...[const SizedBox(height: 13), InlineError(error!,
        onRetry: () => ref.invalidate(projectDraftProvider(widget.draft.projectId)))],
      if (notice != null) ...[const SizedBox(height: 13), SurfaceCard(color: const Color(0xFFEAF8F3),
        child: Row(children: [const Icon(Icons.check_circle, color: AppColors.green),
          const SizedBox(width: 8), Text(notice!, style: const TextStyle(color: AppColors.green))]))],
      const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton(onPressed: saving ? null : () => context.go('/projects/${widget.draft.projectId}/overview'),
          child: const Text('Back to overview')),
        OutlinedButton.icon(onPressed: saving ? null : () => save(),
          icon: const Icon(Icons.save_outlined), label: const Text('Save Draft')),
        FilledButton.icon(onPressed: saving ? null : () => save(proceed: true),
          icon: Icon(saving ? Icons.hourglass_empty : Icons.arrow_forward),
          label: Text(saving ? 'Saving…' : 'Save & Continue')),
      ]),
    ]));
}
