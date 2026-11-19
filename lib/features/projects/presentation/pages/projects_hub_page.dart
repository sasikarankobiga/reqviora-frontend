import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:reqviora_frontend/shared/layouts/responsive_page_shell.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_tokens.dart';
import '../view_data/project_hub_view_data.dart';
import '../widgets/project_preview_card.dart';

/// REQVIORA Option A: presentation-only creative projects workspace.
/// Data, navigation and persistence are supplied by Developer B later.
class ProjectsHubPage extends StatefulWidget {
  const ProjectsHubPage({
    super.key,
    this.status = ProjectsHubStatus.empty,
    this.projects = const [],
    this.onCreateProject,
    this.onOpenProject,
    this.onResumeProject,
    this.onSearchChanged,
    this.onFilterChanged,
    this.onRetry,
    this.errorMessage,
  });

  final ProjectsHubStatus status;
  final List<ProjectHubViewData> projects;
  final VoidCallback? onCreateProject;
  final ValueChanged<String>? onOpenProject;
  final ValueChanged<String>? onResumeProject;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<HubProjectFilter>? onFilterChanged;
  final VoidCallback? onRetry;
  final String? errorMessage;

  @override
  State<ProjectsHubPage> createState() => _ProjectsHubPageState();
}

class _ProjectsHubPageState extends State<ProjectsHubPage> {
  final _queryController = TextEditingController();
  HubProjectFilter _filter = HubProjectFilter.all;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {});
    widget.onSearchChanged?.call(value);
  }

  void _setFilter(HubProjectFilter value) {
    setState(() => _filter = value);
    widget.onFilterChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF8),
      body: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _HubGuides()))),
        ResponsivePageShell(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final mobile = width < 600;
            final desktop = width >= 900;
            return Column(
              key: Key(mobile ? 'hub-mobile-layout' : desktop ? 'hub-desktop-layout' : 'hub-tablet-layout'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(mobile),
                SizedBox(height: mobile ? 35 : 47),
                _hero(mobile, desktop),
                SizedBox(height: mobile ? 34 : 46),
                _content(mobile, desktop),
                const SizedBox(height: 38),
                const Text('REQVIORA  /  MAKE IDEAS TANGIBLE',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ReqvioraTokens.textSecondary,
                      letterSpacing: 2, fontSize: 10)),
              ],
            );
          }),
        ),
      ]),
    );
  }

  Widget _header(bool mobile) {
    return Row(children: [
      const Icon(Icons.adjust, color: ReqvioraTokens.accentPurple, size: 26),
      const SizedBox(width: 8),
      const Flexible(child: Text('REQVIORA',
        style: TextStyle(fontFamily: 'Georgia', fontSize: 24,
          color: ReqvioraTokens.textPrimary))),
      const Spacer(),
      if (!mobile)
        const Padding(padding: EdgeInsets.only(right: 17),
          child: Text('THE DESIGN WORKSPACE',
            style: TextStyle(fontSize: 10, letterSpacing: 1.8,
              color: ReqvioraTokens.textSecondary))),
      const Icon(Icons.auto_awesome_outlined, size: 19,
        color: ReqvioraTokens.accentPurple),
    ]);
  }

  Widget _hero(bool mobile, bool desktop) {
    final headline = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('YOUR IDEAS, IN MOTION',
        style: TextStyle(color: ReqvioraTokens.accentPurple,
          fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Text.rich(TextSpan(children: [
        const TextSpan(text: 'Design begins\nwith a '),
        const TextSpan(text: 'question.', style: TextStyle(
          color: ReqvioraTokens.accentPurple, fontStyle: FontStyle.italic)),
      ]), style: TextStyle(fontFamily: 'Georgia',
        fontSize: mobile ? 38 : desktop ? 52 : 45,
        height: 1.09, letterSpacing: -1.3,
        color: ReqvioraTokens.textPrimary)),
      const SizedBox(height: 15),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 530),
        child: Text('Bring a requirement to life. Continue a blueprint, revisit a design, or begin something entirely new.',
          style: TextStyle(fontSize: 14, height: 1.65,
            color: ReqvioraTokens.textSecondary))),
    ]);
    final action = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min, children: [
      FilledButton.icon(
        key: const Key('hub-create-project'),
        onPressed: widget.onCreateProject,
        icon: const Icon(Icons.add, size: 19),
        label: const Text('Create Project'),
        style: FilledButton.styleFrom(
          backgroundColor: ReqvioraTokens.accentPurple,
          foregroundColor: Colors.white,
          minimumSize: const Size(190, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      const SizedBox(height: 11),
      const Text('START WITH AN IDEA  ·  SHAPE WHAT COMES NEXT',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 9, letterSpacing: 1.2,
          color: ReqvioraTokens.textSecondary)),
    ]);
    if (!desktop) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        headline, const SizedBox(height: 27),
        if (mobile) action else Align(alignment: Alignment.centerLeft,
          child: SizedBox(width: 245, child: action)),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(flex: 7, child: headline),
      const SizedBox(width: 32),
      Expanded(flex: 3, child: Padding(
        padding: const EdgeInsets.only(bottom: 8), child: action)),
    ]);
  }

  Widget _content(bool mobile, bool desktop) {
    if (widget.status == ProjectsHubStatus.loading) {
      return _statePanel(
        key: 'hub-loading', icon: Icons.hourglass_top_outlined,
        heading: 'Gathering your workspace',
        message: 'Preparing the projects and designs you can continue.',
        loading: true,
      );
    }
    if (widget.status == ProjectsHubStatus.error) {
      return _statePanel(
        key: 'hub-error', icon: Icons.layers_clear_outlined,
        heading: 'Your workspace is unavailable',
        message: widget.errorMessage ?? 'We could not load the projects. Try again.',
        action: widget.onRetry == null ? null : TextButton.icon(
          key: const Key('hub-retry'),
          onPressed: widget.onRetry, icon: const Icon(Icons.refresh),
          label: const Text('Try again')),
      );
    }
    if (widget.status == ProjectsHubStatus.empty || widget.projects.isEmpty) {
      return _statePanel(
        key: 'hub-empty', icon: Icons.dashboard_customize_outlined,
        heading: 'Every great design starts somewhere',
        message: 'Your project library is still a blank page. Create your first project to begin.',
      );
    }

    final q = _queryController.text.trim().toLowerCase();
    final filtered = widget.projects.where((p) {
      final matchingText = p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
      final matchingFilter = switch (_filter) {
        HubProjectFilter.all => true,
        HubProjectFilter.inProgress => !p.isCompleted,
        HubProjectFilter.completed => p.isCompleted,
      };
      return matchingText && matchingFilter;
    }).toList(growable: false);
    final recent = widget.projects.take(3).toList(growable: false);
    final resume = widget.projects.where((p) => !p.isCompleted).firstOrNull;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (resume != null) ...[
        _sectionHeading('01  /  PICK UP WHERE YOU LEFT OFF', 'Continue Designing'),
        const SizedBox(height: 17),
        _resumePanel(resume, mobile),
        const SizedBox(height: 42),
      ],
      _sectionHeading('02  /  THE WORK IN PROGRESS', 'Recent Projects'),
      const SizedBox(height: 17),
      _projectGrid(recent, desktop),
      const SizedBox(height: 42),
      _sectionHeading('03  /  YOUR CREATIVE ARCHIVE', 'Project Library'),
      const SizedBox(height: 17),
      _searchFilters(mobile),
      const SizedBox(height: 19),
      if (filtered.isEmpty)
        _statePanel(key: 'hub-no-results', icon: Icons.search_off,
          heading: 'No matching projects',
          message: 'Try another search or choose a different filter.')
      else
        _projectGrid(filtered, desktop),
    ]);
  }

  Widget _sectionHeading(String eyebrow, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(eyebrow, style: const TextStyle(color: ReqvioraTokens.accentPurple,
          fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 28,
        color: ReqvioraTokens.textPrimary)),
    ]);

  Widget _resumePanel(ProjectHubViewData project, bool mobile) {
    final details = Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, children: [
      const Text('IN YOUR STUDIO', style: TextStyle(fontSize: 10,
        letterSpacing: 1.7, color: ReqvioraTokens.accentPurple,
        fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Text(project.name, style: const TextStyle(fontFamily: 'Georgia',
        fontSize: 25, color: ReqvioraTokens.textPrimary)),
      const SizedBox(height: 8),
      Text(project.description, style: const TextStyle(fontSize: 13,
        height: 1.6, color: ReqvioraTokens.textSecondary)),
      const SizedBox(height: 18),
      Align(alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('hub-resume-project'),
          onPressed: widget.onResumeProject == null ? null :
            () => widget.onResumeProject!(project.id),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: const Text('Continue Designing'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ReqvioraTokens.accentPurple,
            side: const BorderSide(color: ReqvioraTokens.accentPurple),
            minimumSize: const Size(0, 46),
          ),
        )),
    ]);
    final miniature = SizedBox(
      width: mobile ? double.infinity : 250,
      child: ProjectPreviewCard(project: project,
        featured: false, onOpen: widget.onOpenProject),
    );
    return Container(
      padding: EdgeInsets.all(mobile ? 18 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0FA).withValues(alpha: .82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6DCEE)),
      ),
      child: mobile
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              details, const SizedBox(height: 20), miniature,
            ])
          : Row(children: [
              Expanded(child: details), const SizedBox(width: 22), miniature,
            ]),
    );
  }

  Widget _projectGrid(List<ProjectHubViewData> projects, bool desktop) {
    return LayoutBuilder(builder: (context, constraints) {
      final count = constraints.maxWidth >= 900 ? 3 :
        constraints.maxWidth >= 560 ? 2 : 1;
      final gap = 16.0;
      final cardWidth = (constraints.maxWidth - gap * (count - 1)) / count;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final project in projects)
          SizedBox(width: cardWidth, child: ProjectPreviewCard(
            project: project, onOpen: widget.onOpenProject)),
      ]);
    });
  }

  Widget _searchFilters(bool mobile) {
    final search = TextField(
      key: const Key('hub-project-search'),
      controller: _queryController,
      onChanged: _search,
      decoration: InputDecoration(
        hintText: 'Search your projects',
        prefixIcon: const Icon(Icons.search, color: ReqvioraTokens.accentPurple),
        filled: true, fillColor: const Color(0xFFFEFCFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: ReqvioraTokens.outline)),
      ),
    );
    final filters = Wrap(spacing: 7, runSpacing: 7, children: [
      _filterChip('All', HubProjectFilter.all),
      _filterChip('In progress', HubProjectFilter.inProgress),
      _filterChip('Completed', HubProjectFilter.completed),
    ]);
    if (mobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        search, const SizedBox(height: 12), filters,
      ]);
    }
    return Row(children: [
      Expanded(child: search), const SizedBox(width: 15),
      Flexible(child: filters),
    ]);
  }

  Widget _filterChip(String name, HubProjectFilter value) {
    return ChoiceChip(
      key: Key('hub-filter-${value.name}'),
      label: Text(name),
      selected: _filter == value,
      onSelected: (_) => _setFilter(value),
      selectedColor: const Color(0xFFEAE3F4),
      labelStyle: const TextStyle(fontSize: 12,
        color: ReqvioraTokens.textPrimary),
      side: const BorderSide(color: ReqvioraTokens.outline),
      showCheckmark: false,
    );
  }

  Widget _statePanel({required String key, required IconData icon,
    required String heading, required String message,
    Widget? action, bool loading = false}) {
    return Container(
      key: Key(key),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 55),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReqvioraTokens.outline),
      ),
      child: Column(children: [
        if (loading)
          const CircularProgressIndicator(key: Key('hub-progress-indicator'))
        else
          Icon(icon, size: 38, color: ReqvioraTokens.accentPurple),
        const SizedBox(height: 18),
        Text(heading, textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 25,
            color: ReqvioraTokens.textPrimary)),
        const SizedBox(height: 10),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 410),
          child: Text(message, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.6,
              color: ReqvioraTokens.textSecondary))),
        if (action != null) ...[const SizedBox(height: 17), action],
      ]),
    );
  }
}

class _HubGuides extends CustomPainter {
  const _HubGuides();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke
      ..color = ReqvioraTokens.accentPurple.withValues(alpha: .055)
      ..strokeWidth = 1;
    final center = Offset(size.width * .76, size.height * .20);
    canvas.drawArc(Rect.fromCircle(center: center, radius: 180),
      -math.pi * .9, math.pi * 1.4, false, paint);
    canvas.drawCircle(center, 105, paint);
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(Offset(center.dx+i*29,center.dy-115),
        Offset(center.dx+i*29,center.dy+115), paint);
      canvas.drawLine(Offset(center.dx-115,center.dy+i*29),
        Offset(center.dx+115,center.dy+i*29), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
