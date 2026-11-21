import 'package:flutter/material.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_tokens.dart';
import '../view_data/project_hub_view_data.dart';

/// A presentation-only, accessible card with a miniature design artifact.
class ProjectPreviewCard extends StatefulWidget {
  const ProjectPreviewCard({
    required this.project,
    required this.onOpen,
    super.key,
    this.featured = false,
  });

  final ProjectHubViewData project;
  final ValueChanged<String>? onOpen;
  final bool featured;

  @override
  State<ProjectPreviewCard> createState() => _ProjectPreviewCardState();
}

class _ProjectPreviewCardState extends State<ProjectPreviewCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabledAnimations = MediaQuery.of(context).disableAnimations;
    final duration = disabledAnimations
        ? Duration.zero
        : const Duration(milliseconds: 170);
    final phaseText = switch (widget.project.phase) {
      HubProjectPhase.requirements => 'REQUIREMENTS',
      HubProjectPhase.blueprint => 'BLUEPRINT',
      HubProjectPhase.design => 'DESIGN PREVIEW',
    };

    return Semantics(
      button: true,
      label: 'Open ${widget.project.name}',
      child: AnimatedContainer(
        duration: duration,
        transform: Matrix4.translationValues(0, _hovered && !disabledAnimations ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFCFA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _hovered ? ReqvioraTokens.accentPurple : const Color(0xFFE9E2EB)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF42345E).withValues(alpha: _hovered ? 0.10 : 0.035),
              blurRadius: _hovered ? 19 : 12,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key('hub-project-${widget.project.id}'),
            borderRadius: BorderRadius.circular(15),
            onTap: widget.onOpen == null ? null : () => widget.onOpen!(widget.project.id),
            onHover: (value) { if (mounted) setState(() => _hovered = value); },
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(phaseText,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: ReqvioraTokens.accentPurple, letterSpacing: 1.5))),
                      if (widget.project.isCompleted)
                        const Icon(Icons.check_circle_outline, size: 16, color: ReqvioraTokens.accentPurple),
                      const SizedBox(width: 3),
                      const Icon(Icons.north_east, size: 17, color: ReqvioraTokens.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: widget.featured ? 190 : 150,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _ProjectArtifactPainter(widget.project.phase),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_outlined,
                        size: 14,
                        color: ReqvioraTokens.accentPurple,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          switch (widget.project.phase) {
                            HubProjectPhase.requirements =>
                              'Capture requirements',
                            HubProjectPhase.blueprint =>
                              'Plan the screen layout',
                            HubProjectPhase.design =>
                              'Explore the interface',
                          },
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ReqvioraTokens.accentPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(widget.project.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 20,
                      height: 1.2, color: ReqvioraTokens.textPrimary)),
                  const SizedBox(height: 7),
                  Text(widget.project.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, height: 1.55,
                      color: ReqvioraTokens.textSecondary)),
                  const SizedBox(height: 15),
                  Text(widget.project.updatedLabel,
                    style: const TextStyle(fontSize: 11, color: ReqvioraTokens.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Illustration is meaningful: document -> structural wireframe -> screen UI.
class _ProjectArtifactPainter extends CustomPainter {
  const _ProjectArtifactPainter(this.phase);
  final HubProjectPhase phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 250, size.height / 160);
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..color = const Color(0xFFA89AC5);
    final pale = Paint()..color = const Color(0xFFEAE4F4);
    final pale2 = Paint()..color = const Color(0xFFF5F0FA);
    final purple = Paint()..color = ReqvioraTokens.accentPurple;
    void rect(double x, double y, double w, double h, {Paint? paint, double radius = 4}) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,y,w,h), Radius.circular(radius)),paint ?? line);
    }
    rect(0,0,250,160,paint:pale2,radius:10);
    // Drafting guide grid behind each illustration.
    for (var i = 12.0; i < 250; i += 24) {
      canvas.drawLine(Offset(i, 0), Offset(i,160),
        Paint()..color = const Color(0xFFE9E4F0)..strokeWidth = .6);
    }
    for (var i = 12.0; i < 160; i += 24) {
      canvas.drawLine(Offset(0,i), Offset(250,i),
        Paint()..color = const Color(0xFFE9E4F0)..strokeWidth = .6);
    }
    if (phase == HubProjectPhase.requirements) {
      rect(52,10,146,140,paint:Paint()..color = Colors.white);
      rect(52,10,146,140);
      rect(69,28,87,11,paint:pale);
      for (var i = 0; i < 4; i++) {
        final y = 56.0 + i*20;
        rect(69,y,10,10);
        canvas.drawLine(Offset(87,y+5), Offset(i==3 ? 146 : 176,y+5),line);
      }
      rect(69,136,57,5,paint:pale);
    } else if (phase == HubProjectPhase.blueprint) {
      rect(27,17,196,126,paint:Paint()..color = Colors.white);
      rect(27,17,196,126);
      rect(36,27,178,15,paint:pale);
      rect(36,51,58,82);
      rect(102,51,112,38);
      rect(102,97,52,36);
      rect(162,97,52,36);
      canvas.drawLine(const Offset(102,51),const Offset(214,89),line);
      canvas.drawLine(const Offset(162,97),const Offset(214,133),line);
    } else {
      rect(17,13,216,134,paint:Paint()..color = Colors.white);
      rect(17,13,216,134);
      rect(17,13,216,16,paint:pale);
      rect(27,39,47,98,paint:pale);
      rect(84,39,139,35,paint:pale2);
      rect(84,82,65,55);
      rect(158,82,65,55);
      final curve = Path()..moveTo(92,127)..quadraticBezierTo(106,99,121,117)
        ..quadraticBezierTo(136,132,143,96);
      canvas.drawPath(curve,Paint()..color = ReqvioraTokens.accentPurple
        ..style = PaintingStyle.stroke..strokeWidth = 2.6);
      rect(166,92,49,8,paint:pale);
      rect(166,107,34,8,paint:pale);
      rect(166,122,43,8,paint:purple);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProjectArtifactPainter oldDelegate) => oldDelegate.phase != phase;
}
