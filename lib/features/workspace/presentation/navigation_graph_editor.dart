import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workspace_providers.dart';
import '../domain/workspace.dart';

class NavigationGraphEditor extends ConsumerStatefulWidget {
  const NavigationGraphEditor({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<NavigationGraphEditor> createState() =>
      _NavigationGraphEditorState();
}

class _NavigationGraphEditorState extends ConsumerState<NavigationGraphEditor> {
  static const nodeWidth = 180.0;
  static const nodeHeight = 80.0;

  final positions = <String, Offset>{};

  bool saving = false;
  bool dirty = false;

  String? error;

  List<Map<String, dynamic>> get screens => widget.workspace.items('screens');

  List<Map<String, dynamic>> get routes => widget.workspace.items('routes');

  double get canvasWidth => 1000;

  double get canvasHeight =>
      math.max(480.0, ((screens.length + 2) ~/ 3) * 150.0 + 100);

  @override
  void initState() {
    super.initState();
    loadPositions();
  }

  @override
  void didUpdateWidget(covariant NavigationGraphEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.workspace.projectId != widget.workspace.projectId) {
      dirty = false;
      error = null;
      loadPositions();
      return;
    }

    if (!dirty && oldWidget.workspace.version != widget.workspace.version) {
      loadPositions();
    }
  }

  Offset bounded(Offset value) => Offset(
    value.dx.clamp(0.0, canvasWidth - nodeWidth).toDouble(),
    value.dy.clamp(0.0, canvasHeight - nodeHeight).toDouble(),
  );

  void loadPositions({bool reset = false}) {
    positions.clear();

    final saved = widget.workspace.fields('navigationLayout');
    final nodes = screens;

    for (var i = 0; i < nodes.length; i++) {
      final id = nodes[i]['id'].toString();
      final value = saved[id];

      final fallback = Offset(30.0 + (i % 3) * 300, 30.0 + (i ~/ 3) * 150);

      if (!reset && value is Map && value['x'] is num && value['y'] is num) {
        final x = (value['x'] as num).toDouble();
        final y = (value['y'] as num).toDouble();

        positions[id] =
            x.isFinite && y.isFinite ? bounded(Offset(x, y)) : fallback;
      } else {
        positions[id] = fallback;
      }
    }
  }

  Future<void> saveLayout() async {
    if (saving || !dirty) return;

    final projectId = widget.workspace.projectId;
    final version = widget.workspace.version;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ref.read(workspaceRepositoryProvider).save(
        projectId,
        'navigationLayout',
        version,
        {
          for (final entry in positions.entries)
            entry.key: {'x': entry.value.dx, 'y': entry.value.dy},
        },
      );

      if (!mounted) return;

      setState(() => dirty = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Navigation layout saved')));

      ref.invalidate(workspaceProvider(projectId));
    } catch (failure) {
      if (mounted) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (screens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Add screens in Step 02 to build your navigation graph.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Visual Navigation Map', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Drag screen nodes to arrange your navigation. '
          'Arrows represent the saved routes below.',
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text('${screens.length} screens')),
            Chip(label: Text('${routes.length} routes')),

            OutlinedButton.icon(
              onPressed:
                  saving
                      ? null
                      : () {
                        setState(() {
                          loadPositions(reset: true);
                          dirty = true;
                        });
                      },
              icon: const Icon(Icons.grid_view),
              label: const Text('Auto Layout'),
            ),

            FilledButton.icon(
              onPressed: saving || !dirty ? null : saveLayout,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save Layout'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (dirty) const Text('You have unsaved layout changes.'),

        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),

        if (saving) const LinearProgressIndicator(),

        Container(
          height: 490,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: InteractiveViewer(
            constrained: false,
            minScale: 0.4,
            maxScale: 2,
            boundaryMargin: const EdgeInsets.all(80),
            child: SizedBox(
              width: canvasWidth,
              height: canvasHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePainter(
                        positions: Map.of(positions),
                        routes: routes,
                        lineColor: theme.colorScheme.primary,
                        gridColor: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),

                  for (final screen in screens)
                    if (positions.containsKey(screen['id'].toString()))
                      Positioned(
                        left: positions[screen['id'].toString()]!.dx,
                        top: positions[screen['id'].toString()]!.dy,
                        width: nodeWidth,
                        height: nodeHeight,
                        child: GestureDetector(
                          onPanUpdate:
                              saving
                                  ? null
                                  : (details) {
                                    final id = screen['id'].toString();

                                    setState(() {
                                      positions[id] = bounded(
                                        positions[id]! + details.delta,
                                      );

                                      dirty = true;
                                    });
                                  },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.move,
                            child: Material(
                              elevation: 3,
                              color: theme.colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.web_asset_outlined,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        (screen['name'] ?? 'Screen').toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.drag_indicator, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        const Text(
          'Use the existing route editor to add, edit or remove connections.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.positions,
    required this.routes,
    required this.lineColor,
    required this.gridColor,
  });

  final Map<String, Offset> positions;
  final List<Map<String, dynamic>> routes;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.35)
          ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linePaint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;

    final arrowPaint =
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;

    for (final route in routes) {
      final from = positions[route['fromScreenId'].toString()];
      final to = positions[route['toScreenId'].toString()];

      if (from == null || to == null) continue;

      final a = from + const Offset(90, 40);
      final b = to + const Offset(90, 40);

      final delta = b - a;

      if (delta.distance < 1) {
        canvas.drawArc(
          Rect.fromLTWH(from.dx + 145, from.dy - 25, 70, 65),
          -math.pi / 2,
          math.pi * 1.7,
          false,
          linePaint,
        );

        continue;
      }

      final direction = delta / delta.distance;

      final dx = direction.dx.abs();
      final dy = direction.dy.abs();

      final edgeDistance = math.min(
        dx < 0.001 ? double.infinity : 90 / dx,
        dy < 0.001 ? double.infinity : 40 / dy,
      );

      final start = a + direction * edgeDistance;
      final end = b - direction * edgeDistance;

      if (delta.distance <= edgeDistance * 2) continue;

      canvas.drawLine(start, end, linePaint);

      final angle = math.atan2(direction.dy, direction.dx);

      final arrow =
          Path()
            ..moveTo(end.dx, end.dy)
            ..lineTo(
              end.dx - 12 * math.cos(angle - math.pi / 6),
              end.dy - 12 * math.sin(angle - math.pi / 6),
            )
            ..lineTo(
              end.dx - 12 * math.cos(angle + math.pi / 6),
              end.dy - 12 * math.sin(angle + math.pi / 6),
            )
            ..close();

      canvas.drawPath(arrow, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => true;
}
