import 'package:flutter/material.dart';

/// Local visual mockup of the selected platform.
/// This is not a generated blueprint, saved project or API result.
class CreateProjectStoryPreview extends StatefulWidget {
  const CreateProjectStoryPreview({
    super.key,
    this.projectName = '',
    this.projectDescription = '',
    this.primaryPlatform = 'web',
  });

  final String projectName;
  final String projectDescription;
  final String primaryPlatform;

  @override
  State<CreateProjectStoryPreview> createState() =>
      _CreateProjectStoryPreviewState();
}

class _CreateProjectStoryPreviewState extends State<CreateProjectStoryPreview> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

    final name = widget.projectName.trim().isEmpty
        ? 'Your new project'
        : widget.projectName.trim();

    final description = widget.projectDescription.trim().isEmpty
        ? 'Your concept, brought into focus.'
        : widget.projectDescription.trim();

    final platform = switch (widget.primaryPlatform) {
      'mobile' => 'mobile',
      'desktop' => 'desktop',
      _ => 'web',
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        key: const Key('create-story-preview'),
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(
                alpha: _hovered ? 0.13 : 0.07,
              ),
              blurRadius: _hovered ? 30 : 18,
              offset: Offset(0, _hovered ? 10 : 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: scheme.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Live preview',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'LOCAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'A visual concept based on your inputs.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.55),
                      scheme.surfaceContainerHighest,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: KeyedSubtree(
                    key: ValueKey(platform),
                    child: switch (platform) {
                      'mobile' => _MobileDevice(
                          name: name,
                          description: description,
                        ),
                      'desktop' => _DesktopDevice(
                          name: name,
                          description: description,
                        ),
                      _ => _WebDevice(
                          name: name,
                          description: description,
                        ),
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: scheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${platform.toUpperCase()} concept preview',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Illustrative only — nothing has been generated or saved.',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebDevice extends StatelessWidget {
  const _WebDevice({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('create-device-web'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: scheme.surfaceContainerHigh,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  CircleAvatar(
                    radius: 3,
                    backgroundColor:
                        i == 0 ? scheme.primary : scheme.outlineVariant,
                  ),
                  const SizedBox(width: 5),
                ],
                const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'preview.local',
                      style: TextStyle(
                        fontSize: 9,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _DeviceContent(
            name: name,
            description: description,
            compact: false,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _MobileDevice extends StatelessWidget {
  const _MobileDevice({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        key: const Key('create-device-mobile'),
        constraints: const BoxConstraints(maxWidth: 215),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: scheme.onSurface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 17,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Container(
            color: scheme.surface,
            child: Column(
              children: [
                Container(
                  height: 24,
                  alignment: Alignment.center,
                  child: Container(
                    width: 55,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.onSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                _DeviceContent(
                  name: name,
                  description: description,
                  compact: true,
                ),
                const SizedBox(height: 25),
                Container(
                  width: 62,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 9),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(5),
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

class _DesktopDevice extends StatelessWidget {
  const _DesktopDevice({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          key: const Key('create-device-desktop'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.65),
              width: 5,
            ),
          ),
          child: Column(
            children: [
              Container(
                height: 24,
                color: scheme.surfaceContainerHigh,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(
                      Icons.grid_view_rounded,
                      size: 13,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Workspace',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.crop_square,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 156,
                    color: scheme.primaryContainer,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Icon(Icons.dashboard_outlined,
                            size: 16, color: scheme.primary),
                        const SizedBox(height: 15),
                        Icon(Icons.layers_outlined,
                            size: 16, color: scheme.primary),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _DeviceContent(
                      name: name,
                      description: description,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 16,
          color: scheme.onSurface.withValues(alpha: 0.7),
        ),
        Container(
          width: 100,
          height: 6,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }
}

class _DeviceContent extends StatelessWidget {
  const _DeviceContent({
    required this.name,
    required this.description,
    required this.compact,
  });

  final String name;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REQVIORA CONCEPT',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 9),
          AnimatedSwitcher(
            duration: duration,
            child: Text(
              name,
              key: ValueKey(name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 15 : 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 7),
          AnimatedSwitcher(
            duration: duration,
            child: Text(
              description,
              key: ValueKey(description),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 8,
            width: 105,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniCard(color: scheme.primaryContainer)),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniCard(color: scheme.surfaceContainerHighest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
