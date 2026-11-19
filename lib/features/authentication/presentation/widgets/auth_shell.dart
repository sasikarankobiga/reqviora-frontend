import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:reqviora_frontend/shared/layouts/responsive_page_shell.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_tokens.dart';

/// Option A — Interactive Editorial Design Studio.
/// Owns presentation only; authentication stays in LoginPage/RegisterPage.
class AuthShell extends StatefulWidget {
  const AuthShell({
    required this.title,
    required this.subtitle,
    required this.form,
    this.isRegister = false,
    this.onShowLogin,
    this.onShowRegister,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final bool isRegister;
  final VoidCallback? onShowLogin;
  final VoidCallback? onShowRegister;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline;
  bool _started = false;
  bool _manualSelection = false;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _timeline = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;

    if (reduced) {
      _timeline.value = 1;
    } else if (!_started) {
      _timeline.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  void _selectStage(int stage) {
    setState(() {
      _manualSelection = true;
      _selected = stage;
    });

    if (MediaQuery.of(context).disableAnimations) {
      _timeline.value = 1;
    } else {
      _timeline.animateTo(
        (stage + 1) / 3,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final motionOff = MediaQuery.of(context).disableAnimations;
    final localTheme = base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ReqvioraTokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: ReqvioraTokens.accentPurple,
            width: 2,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return ReqvioraTokens.outline;
            }
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF49347F);
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF7658B5);
            }
            return ReqvioraTokens.accentPurple;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.disabled)
                  ? ReqvioraTokens.textSecondary
                  : Colors.white),
        ),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAF8),
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _BlueprintBackground()),
              ),
            ),
            ResponsivePageShell(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final desktop = width >= 900;
                  final mobile = width < 600;

                  final story = AnimatedBuilder(
                    animation: _timeline,
                    builder: (context, _) {
                      final progress = motionOff ? 1.0 : _timeline.value;
                      final current = _manualSelection
                          ? _selected
                          : ((progress * 3).floor()).clamp(0, 2);

                      return _EditorialStory(
                        progress: progress,
                        selected: current,
                        onSelect: _selectStage,
                        mobile: mobile,
                        reduceMotion: motionOff,
                      );
                    },
                  );

                  final auth = _AuthCard(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    form: widget.form,
                    isRegister: widget.isRegister,
                    onShowLogin: widget.onShowLogin,
                    onShowRegister: widget.onShowRegister,
                  );

                  if (!desktop) {
                    return Column(
                      key: const Key('auth-stacked-layout'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _StudioHeader(),
                        const SizedBox(height: 26),
                        story,
                        const SizedBox(height: 28),
                        Center(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 530),
                            child: auth,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      const _StudioHeader(),
                      const SizedBox(height: 36),
                      Row(
                        key: const Key('auth-split-layout'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 12, child: story),
                          const SizedBox(width: 30),
                          Expanded(
                            flex: 9,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 34),
                              child: auth,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.adjust,
          color: ReqvioraTokens.accentPurple,
          size: 28,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            'REQVIORA',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontFamily: 'Georgia',
                  letterSpacing: -0.5,
                  fontSize: 25,
                ),
          ),
        ),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width >= 700)
          Text(
            'A REQUIREMENT DESIGN STUDIO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  color: ReqvioraTokens.textSecondary,
                ),
          ),
      ],
    );
  }
}

class _EditorialStory extends StatelessWidget {
  const _EditorialStory({
    required this.progress,
    required this.selected,
    required this.onSelect,
    required this.mobile,
    required this.reduceMotion,
  });

  final double progress;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool mobile;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final headlineProgress = reduceMotion
        ? 1.0
        : (progress * 3).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: headlineProgress,
          child: Transform.translate(
            offset: Offset(0, (1 - headlineProgress) * 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FROM REQUIREMENTS TO EXPERIENCE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 2.1,
                        color: ReqvioraTokens.accentPurple,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Transform\nRequirements\ninto ',
                      ),
                      TextSpan(
                        text: 'Design',
                        style: const TextStyle(
                          color: ReqvioraTokens.accentPurple,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: mobile ? 38 : 49,
                    height: 1.07,
                    letterSpacing: -1.8,
                    color: ReqvioraTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Text(
                    'Turn ideas and product requirements into '
                    'structured blueprints and beautiful, '
                    'ready-to-explore interface designs.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: ReqvioraTokens.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: mobile ? 24 : 34),
        Semantics(
          label: 'Interactive transformation stages',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mobile)
                Column(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      _ArtifactCard(
                        index: i,
                        selected: selected == i,
                        compact: true,
                        revealed: true,
                        onTap: () => onSelect(i),
                      ),
                      if (i < 2)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: Icon(
                            Icons.arrow_downward,
                            size: 17,
                            color: ReqvioraTokens.accentPurple,
                          ),
                        ),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: _ArtifactCard(
                          index: i,
                          selected: selected == i,
                          compact: false,
                          revealed: reduceMotion ||
                              progress >= (i * 0.2),
                          onTap: () => onSelect(i),
                        ),
                      ),
                      if (i < 2)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 15,
                            color: ReqvioraTokens.accentPurple,
                          ),
                        ),
                    ],
                  ],
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: _ProgressSegment(
                        key: Key('auth-progress-$i'),
                        active: selected == i,
                        filled: i <= selected,
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 7),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Stage ${selected + 1} of 3  ·  '
                '${const ['Requirement', 'Blueprint', 'UI Preview'][selected]}',
                key: const Key('auth-stage-status'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: ReqvioraTokens.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtifactCard extends StatefulWidget {
  const _ArtifactCard({
    required this.index,
    required this.selected,
    required this.compact,
    required this.revealed,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool compact;
  final bool revealed;
  final VoidCallback onTap;

  @override
  State<_ArtifactCard> createState() => _ArtifactCardState();
}

class _ArtifactCardState extends State<_ArtifactCard> {
  bool _hover = false;

  static const titles = [
    'Requirement Note',
    'Blueprint',
    'UI Preview',
  ];

  static const subtitles = [
    'Capture the idea',
    'Shape the structure',
    'Explore the interface',
  ];

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    final duration =
        reduced ? Duration.zero : const Duration(milliseconds: 220);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Select ${titles[widget.index]}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedOpacity(
          duration: duration,
          opacity: widget.revealed ? 1 : 0.38,
          child: AnimatedContainer(
            duration: duration,
            transform: Matrix4.translationValues(
              0,
              _hover && !reduced ? -4 : 0,
              0,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? const Color(0xFFFBF8FF)
                  : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: widget.selected
                    ? ReqvioraTokens.accentPurple
                    : ReqvioraTokens.outline,
                width: widget.selected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: ReqvioraTokens.accentPurple.withValues(
                    alpha: _hover ? 0.16 : 0.06,
                  ),
                  blurRadius: _hover ? 18 : 9,
                  offset: Offset(0, _hover ? 9 : 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('auth-stage-${widget.index}'),
                borderRadius: BorderRadius.circular(13),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: widget.compact
                      ? Row(
                          children: [
                            SizedBox(
                              width: 76,
                              height: 58,
                              child: CustomPaint(
                                painter: _ArtifactPainter(widget.index),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _label(context)),
                            if (widget.selected)
                              const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: ReqvioraTokens.accentPurple,
                              ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 86,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _ArtifactPainter(widget.index),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _label(context),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titles[widget.index],
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitles[widget.index],
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ReqvioraTokens.textSecondary,
              ),
        ),
      ],
    );
  }
}

/// Draws actual miniature requirement, wireframe and UI layouts.
/// No image assets or generic icons are required.
class _ArtifactPainter extends CustomPainter {
  const _ArtifactPainter(this.kind);
  final int kind;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()
      ..color = const Color(0xFF988BB9)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0xFFEAE3F7)
      ..style = PaintingStyle.fill;
    final accent = Paint()
      ..color = ReqvioraTokens.accentPurple
      ..style = PaintingStyle.fill;

    void rectangle(
      double x,
      double y,
      double width,
      double height, {
      bool filled = false,
    }) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, height),
          const Radius.circular(3),
        ),
        filled ? fill : ink,
      );
    }

    rectangle(2, 2, w - 4, h - 4);

    if (kind == 0) {
      rectangle(12, 12, w * 0.49, 9, filled: true);
      for (var i = 0; i < 3; i++) {
        final y = 32.0 + i * 15;
        rectangle(13, y, 7, 7);
        canvas.drawLine(
          Offset(26, y + 4),
          Offset(w - 14 - i * 7, y + 4),
          ink,
        );
      }
      rectangle(12, h - 16, w * 0.35, 8, filled: true);
    } else if (kind == 1) {
      for (var x = 10.0; x < w; x += 13) {
        canvas.drawLine(Offset(x, 2), Offset(x, h - 2), ink..strokeWidth = .35);
      }
      for (var y = 10.0; y < h; y += 13) {
        canvas.drawLine(Offset(2, y), Offset(w - 2, y), ink);
      }
      ink.strokeWidth = 1.3;
      rectangle(13, 13, w - 26, h - 26);
      rectangle(19, 19, w - 38, 8, filled: true);
      rectangle(19, 34, (w - 44) * 0.39, h - 55);
      rectangle(w * 0.49, 34, w * 0.34, h - 55);
      canvas.drawLine(
        Offset(w * 0.49, 34),
        Offset(w * 0.83, h - 21),
        ink,
      );
    } else {
      rectangle(9, 9, w - 18, h - 18);
      rectangle(9, 9, w - 18, 10, filled: true);
      rectangle(15, 25, w * 0.22, h - 39, filled: true);
      rectangle(w * 0.32, 25, w * 0.52, 10, filled: true);
      rectangle(w * 0.32, 41, w * 0.52, h - 56);
      final path = Path()
        ..moveTo(w * 0.35, h - 23)
        ..quadraticBezierTo(
          w * 0.49, h - 49, w * 0.59, h - 36,
        )
        ..quadraticBezierTo(
          w * 0.69, h - 19, w * 0.81, h - 44,
        );
      canvas.drawPath(
        path,
        ink
          ..strokeWidth = 2
          ..color = ReqvioraTokens.accentPurple,
      );
      canvas.drawCircle(Offset(w * 0.82, 15), 2.5, accent);
    }
  }

  @override
  bool shouldRepaint(covariant _ArtifactPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.active,
    required this.filled,
    super.key,
  });

  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      height: active ? 5 : 3,
      decoration: BoxDecoration(
        color: filled
            ? ReqvioraTokens.accentPurple
            : ReqvioraTokens.outline,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.isRegister,
    required this.onShowLogin,
    required this.onShowRegister,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final bool isRegister;
  final VoidCallback? onShowLogin;
  final VoidCallback? onShowRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: Container(
        key: const Key('auth-form-card'),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFEFCFA),
              Color(0xFFFAF7FB),
            ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFE8E1EB),
            width: 0.85,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C332449),
              blurRadius: 28,
              offset: Offset(0, 13),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 27,
                  height: 1.5,
                  color: ReqvioraTokens.accentPurple,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'THE CREATIVE WORKSPACE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ReqvioraTokens.accentPurple,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              'Welcome to',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ReqvioraTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'REQVIORA',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFamily: 'Georgia',
                fontSize: 27,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.6,
                color: ReqvioraTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: ReqvioraTokens.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: _AuthTab(
                    label: 'Sign In',
                    active: !isRegister,
                    onTap: onShowLogin,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AuthTab(
                    label: 'Create Account',
                    active: isRegister,
                    onTap: onShowRegister,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 13),
            form,
          ],
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.active,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? null : onTap,
          borderRadius: BorderRadius.circular(7),
          hoverColor: const Color(0x0A6750A4),
          focusColor: const Color(0x126750A4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: TextStyle(
                    color: active
                        ? ReqvioraTokens.accentPurple
                        : ReqvioraTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: duration,
                  height: active ? 2 : 1,
                  decoration: BoxDecoration(
                    color: active
                        ? ReqvioraTokens.accentPurple
                        : ReqvioraTokens.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _BlueprintBackground extends CustomPainter {
  const _BlueprintBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ReqvioraTokens.accentPurple.withValues(alpha: 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width * 0.30, size.height * 0.37);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 220),
      -math.pi * 0.9,
      math.pi * 1.2,
      false,
      paint,
    );
    canvas.drawCircle(center, 105, paint);

    for (var i = -4; i <= 4; i++) {
      canvas.drawLine(
        Offset(center.dx + i * 34, center.dy - 155),
        Offset(center.dx + i * 34, center.dy + 155),
        paint..strokeWidth = .5,
      );
      canvas.drawLine(
        Offset(center.dx - 155, center.dy + i * 34),
        Offset(center.dx + 155, center.dy + i * 34),
        paint,
      );
    }

    paint.strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - 160, center.dy + 130),
      Offset(center.dx + 175, center.dy - 145),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}