import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/projects_providers.dart';

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key});
  @override ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}
class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final description = TextEditingController();
  String category = 'Software / SaaS';
  final selectedTargets = <String>{'web'};
  String? error;
  bool saving = false;
  @override void dispose() { name.dispose(); description.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() { saving = true; error = null; });
    try {
      final project = await ref.read(projectsRepositoryProvider).create(
        name: name.text.trim(), description: description.text.trim(),
        category: category, designTargets: selectedTargets.toList());
      ref.invalidate(projectsProvider);
      if (mounted) context.go('/projects/${project.id}/overview');
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) => AppShell(pageTitle: 'Workspace / Create Project',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageIntro(eyebrow: 'Project setup', title: 'Create a new project',
        subtitle: 'Start with the basics. You can refine these details inside Builder Step 01.'),
      const SizedBox(height: 25), LayoutBuilder(builder: (context, size) {
        final wide = size.maxWidth > 830;
        final fields = SurfaceCard(child: Form(key: form, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Project details', subtitle: 'A simple, single-screen setup.'),
          const SizedBox(height: 22),
          const _FieldName('Project name *'),
          TextFormField(controller: name, maxLength: 160,
            decoration: const InputDecoration(hintText: 'e.g. Coffee Shop App', counterText: ''),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a project name' : null),
          const SizedBox(height: 17), const _FieldName('Description'),
          TextFormField(controller: description, maxLines: 3, maxLength: 10000,
            decoration: const InputDecoration(hintText: 'What problem will your software solve?', counterText: '')),
          const SizedBox(height: 17), const _FieldName('Category / industry'),
          DropdownButtonFormField<String>(initialValue: category,
            decoration: const InputDecoration(), isExpanded: true,
            items: ['Software / SaaS', 'Food & Beverage', 'E-commerce', 'Education',
              'Healthcare', 'Finance', 'Other'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (v) { if (v != null) setState(() => category = v); }),
          const SizedBox(height: 19), const _FieldName('Workspace'),
          const SurfaceCard(color: Color(0xFFFAFAFE), padding: EdgeInsets.all(14),
            child: Row(children: [Icon(Icons.workspaces_outlined, color: AppColors.purple, size: 20),
              SizedBox(width: 10), Expanded(child: Text('Personal workspace · local demo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)))])),
          const SizedBox(height: 21), const _FieldName('Design target *'),
          const Text('Select the customer interface profiles to design.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 8), Wrap(spacing: 9, runSpacing: 7, children:
            ['web','mobile','desktop'].map((target) => FilterChip(
              label: Text(target[0].toUpperCase() + target.substring(1)),
              selected: selectedTargets.contains(target),
              onSelected: (v) => setState(() {
                if (v) { selectedTargets.add(target); }
                else if (selectedTargets.length > 1) { selectedTargets.remove(target); }
              }), selectedColor: AppColors.purple.withValues(alpha: .15),
              checkmarkColor: AppColors.purple)).toList()),
          if (error != null) ...[const SizedBox(height: 15),
            Text(error!, style: const TextStyle(color: Color(0xFFCE4455)))],
          const SizedBox(height: 28), Row(children: [
            OutlinedButton(onPressed: saving ? null : () => context.go('/projects'),
              child: const Text('Cancel')),
            const SizedBox(width: 12), Expanded(child: FilledButton.icon(onPressed: saving ? null : submit,
              icon: Icon(saving ? Icons.hourglass_empty : Icons.arrow_forward),
              label: Text(saving ? 'Creating…' : 'Create project'))),
          ]),
        ])));
        final aside = SurfaceCard(color: const Color(0xFFFAF9FF), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome, size: 31, color: AppColors.purple),
          const SizedBox(height: 13), Text('Your idea, structured.',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 9), const Text('Your project identity will prefill Step 01 automatically. No duplicate typing.',
            style: TextStyle(color: AppColors.muted, height: 1.6)),
          const SizedBox(height: 21), for (final item in [
            'Create a private project', 'Collect multi-source requirements',
            'Review AI proposals with a human', 'Design across 8 guided steps'])
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.green, size: 18),
              const SizedBox(width: 10), Expanded(child: Text(item, style: const TextStyle(fontSize: 12))),
            ])),
          const SizedBox(height: 9), const SmallLabel('Local demo · not a live customer app'),
        ]));
        if (!wide) return Column(children: [fields, const SizedBox(height: 15), aside]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: fields), const SizedBox(width: 20), Expanded(flex: 4, child: aside)]);
      }),
    ]));
}

class _FieldName extends StatelessWidget {
  const _FieldName(this.text);
  final String text;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7), child: Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)));
}
