import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/config/app_config.dart';
import '../core/auth/auth_session.dart';
import 'theme.dart';
import 'widgets.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.pageTitle, required this.child, this.projectId});
  final String pageTitle;
  final Widget child;
  final String? projectId;
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
    final desktop = size.maxWidth >= 960;
    final sidebar = _Sidebar(projectId: projectId);
    final main = Column(children: [
      _Topbar(title: pageTitle, projectId: projectId),
      Expanded(child: SingleChildScrollView(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1210),
        child: Padding(padding: EdgeInsets.symmetric(
          horizontal: desktop ? 32 : 18, vertical: desktop ? 28 : 20), child: child))))),
    ]);
    if (desktop) return Scaffold(body: Row(children: [SizedBox(width: 245, child: sidebar),
      Expanded(child: main)]));
    return Scaffold(drawer: Drawer(width: 260, child: sidebar),
      appBar: AppBar(title: const _Brand(compact: true)),
      body: Column(children: [Expanded(child: main)]));
  });
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 32, height: 32, decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.blue, AppColors.purple]),
      borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18)),
    const SizedBox(width: 9), Flexible(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('REQVIORA', maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppColors.ink,
        fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -.8)),
      if (!compact) const Text('DESIGN WORKSPACE', maxLines: 1,
        overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8,
        color: AppColors.muted, letterSpacing: 2.1, fontWeight: FontWeight.w800)),
    ])),
  ]);
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.projectId});
  final String? projectId;
  Widget link(BuildContext context, IconData icon, String label, String path) {
    final selected = GoRouterState.of(context).uri.path == path;
    return Padding(padding: const EdgeInsets.only(bottom: 3), child: Material(
      color: selected ? AppColors.purple.withValues(alpha: .11) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, size: 19, color: selected ? AppColors.purple : AppColors.muted),
        title: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? AppColors.purple : AppColors.ink)),
        onTap: () { if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.pop(context); context.go(path); },
      )));
  }
  @override Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Color(0xFFFBFAFF),
      border: Border(right: BorderSide(color: AppColors.line))),
    child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 23, 16, 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.only(left: 12), child: _Brand()),
        const SizedBox(height: 35),
        const Padding(padding: EdgeInsets.fromLTRB(12, 0, 0, 12), child: Text('WORKSPACE', style:
          TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800))),
        link(context, Icons.space_dashboard_rounded, 'Dashboard', '/projects'),
        link(context, Icons.add_box_outlined, 'Create Project', '/projects/new'),
        if (projectId != null) ...[
          const SizedBox(height: 22),
          const Padding(padding: EdgeInsets.fromLTRB(12, 0, 0, 12), child: Text('CURRENT PROJECT', style:
            TextStyle(color: AppColors.muted, fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w800))),
          link(context, Icons.grid_view_rounded, 'Overview', '/projects/$projectId/overview'),
          link(context, Icons.file_present_outlined, 'Input Studio', '/projects/$projectId/sources'),
          link(context, Icons.fact_check_outlined, 'AI Review', '/projects/$projectId/review-input'),
          link(context, Icons.view_week_outlined, '8-Step Builder', '/projects/$projectId/builder/1'),
          link(context, Icons.touch_app_outlined, 'Preview', '/projects/$projectId/preview'),
        ],
        const Spacer(),
        SurfaceCard(color: const Color(0xFFF3F0FF), padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, color: AppColors.purple, size: 21),
            const SizedBox(height: 7), const Text('Local product milestone', style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5), Text(isLocalDemo ? 'Local demo · SQLite storage' : 'Backend requires sign-in',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ])),
        const SizedBox(height: 14),
        Material(type: MaterialType.transparency, child: ListTile(
          dense: true, onTap: isLocalDemo ? null : () => authSession.signOut(), leading: const CircleAvatar(radius: 15,
          backgroundColor: Color(0xFFE8DFFF), child: Icon(Icons.person_outline, size: 18, color: AppColors.purple)),
          title: Text(isLocalDemo ? 'Local demo owner' : 'Account / Sign out', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          subtitle: Text(isLocalDemo ? 'Local development' : 'Sign out of this session', style: const TextStyle(fontSize: 10)))),
      ]))),
  );
}

class _Topbar extends StatelessWidget {
  const _Topbar({required this.title, this.projectId});
  final String title;
  final String? projectId;
  @override Widget build(BuildContext context) => Container(height: 70,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: const BoxDecoration(color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.line))),
    child: Row(children: [
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink))),
      const SmallLabel('V1 · PRODUCT CORE', color: AppColors.purple),
      const SizedBox(width: 12),
      if (projectId != null) IconButton(tooltip: 'Project overview', onPressed: () =>
        context.go('/projects/$projectId/overview'), icon: const Icon(Icons.home_outlined)),
      const CircleAvatar(radius: 17, backgroundColor: Color(0xFFEAE7FB),
        child: Icon(Icons.person_rounded, color: AppColors.purple, size: 19)),
    ]));
}
