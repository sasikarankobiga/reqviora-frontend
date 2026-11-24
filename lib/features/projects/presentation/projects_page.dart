import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_shell.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/projects_providers.dart';
import '../domain/project.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    return AppShell(pageTitle: 'Workspace / Dashboard', child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageIntro(eyebrow: 'Welcome back', title: 'Your design workspace',
        subtitle: 'Turn project ideas into clear, traceable software blueprints.'),
      const SizedBox(height: 23), _Hero(onCreate: () => context.go('/projects/new')),
      const SizedBox(height: 23),
      LayoutBuilder(builder: (context, size) {
        final count = projects.asData?.value.length;
        final stats = <Widget>[
          _Metric(icon: Icons.folder_copy_outlined, title: 'Total projects', value: count?.toString() ?? '—', color: AppColors.purple),
          const _Metric(icon: Icons.view_module_outlined, title: 'Builder stages', value: '08', color: AppColors.blue),
          const _Metric(icon: Icons.shield_outlined, title: 'Project approvals', value: 'Pending', color: AppColors.green),
        ];
        return Wrap(spacing: 14, runSpacing: 14, children: stats.map((widget) => SizedBox(
          width: size.maxWidth >= 690 ? (size.maxWidth - 28) / 3 : size.maxWidth,
          child: widget)).toList());
      }),
      const SizedBox(height: 30),
      SectionTitle('Your projects', subtitle: 'Open a saved project or start something new.',
        trailing: TextButton.icon(onPressed: () => ref.invalidate(projectsProvider),
          icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh'))),
      const SizedBox(height: 15),
      projects.when(
        data: (items) => items.isEmpty
          ? SurfaceCard(child: Padding(padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                const Icon(Icons.auto_awesome_outlined, color: AppColors.purple, size: 46),
                const SizedBox(height: 12), Text('Your first project starts here',
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6), const Text('Create a project to unlock the 8-step design workspace.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 17), FilledButton.icon(onPressed: () => context.go('/projects/new'),
                  icon: const Icon(Icons.add), label: const Text('Create project')),
              ])))
          : LayoutBuilder(builder: (context, size) => Wrap(spacing: 14, runSpacing: 14,
              children: items.map((p) => SizedBox(
                width: size.maxWidth >= 800 ? (size.maxWidth - 28) / 3 : size.maxWidth >= 560
                    ? (size.maxWidth - 14) / 2 : size.maxWidth,
                child: _ProjectCard(project: p))).toList())),
        error: (error, _) => InlineError(error.toString(), onRetry: () => ref.invalidate(projectsProvider)),
        loading: () => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
      ),
      const SizedBox(height: 23),
      SurfaceCard(color: const Color(0xFFFCFBFF), child: Row(children: [
        const Icon(Icons.info_outline, color: AppColors.purple), const SizedBox(width: 13),
        const Expanded(child: Text('Development preview: AI processing, production auth, approval and exports are not active yet.',
          style: TextStyle(color: AppColors.muted, fontSize: 12))),
      ])),
    ]));
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onCreate});
  final VoidCallback onCreate;
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(gradient: const LinearGradient(
      colors: [Color(0xFF6356E9), Color(0xFF8E65F7), Color(0xFF486CE1)],
      begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(23)),
    padding: const EdgeInsets.all(27),
    child: LayoutBuilder(builder: (context, size) => Wrap(runSpacing: 22, spacing: 18,
      crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: size.maxWidth >= 690 ? size.maxWidth * .55 : size.maxWidth,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .17),
                borderRadius: BorderRadius.circular(30)),
              child: const Text('✦  REQVIORA DESIGN STUDIO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: .5))),
            const SizedBox(height: 18), const Text('Design smarter.\nBuild with clarity.', style: TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.14, letterSpacing: -.4)),
            const SizedBox(height: 12), const Text('From messy requirements to a structured, reviewable design journey — all in one workspace.',
              style: TextStyle(color: Color(0xFFEAE8FF), fontSize: 13, height: 1.6)),
            const SizedBox(height: 20), FilledButton.icon(onPressed: onCreate,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.purple),
              icon: const Icon(Icons.add_circle_outline), label: const Text('Start a new project')),
          ])),
        if (size.maxWidth >= 690) SizedBox(width: size.maxWidth * .35,
          child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: .22))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.bolt_rounded, color: Colors.white), SizedBox(width: 8),
                Text('BUILDER JOURNEY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))]),
              const SizedBox(height: 20),
              for (final name in ['Identity & Audience', 'Features & Screens', 'AI UI Design'])
                Padding(padding: const EdgeInsets.only(bottom: 13), child: Row(children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white70, size: 18),
                  const SizedBox(width: 9), Expanded(child: Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 12))),
                ])),
              const SizedBox(height: 3), ClipRRect(borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(value: .375, minHeight: 7,
                  color: Colors.white, backgroundColor: Color(0x668888FF))),
              const SizedBox(height: 8), const Text('8 connected stages',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]))),
      ])));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.title, required this.value, required this.color});
  final IconData icon; final String title; final String value; final Color color;
  @override Widget build(BuildContext context) => SurfaceCard(child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
    const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 3), Text(value, style: const TextStyle(color: AppColors.ink,
        fontSize: 21, fontWeight: FontWeight.w900)),
    ]),
  ]));
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final ProjectSummary project;
  @override Widget build(BuildContext context) => SurfaceCard(child: InkWell(
    onTap: () => context.go('/projects/${project.id}/overview'),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)),
        child: const Icon(Icons.layers_outlined, color: AppColors.purple)),
        const Spacer(), const SmallLabel('Draft')]),
      const SizedBox(height: 16), Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 5), const Text('Design project · 8-stage builder',
        style: TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 16), const Divider(color: AppColors.line),
      const Row(children: [Text('Open workspace',
        style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w800, fontSize: 12)),
        Spacer(), Icon(Icons.arrow_outward, color: AppColors.purple, size: 17)]),
    ])));
}
