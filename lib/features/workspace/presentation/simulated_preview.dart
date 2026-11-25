import 'package:flutter/material.dart';
import '../../builder/domain/registry/v4_visibility_rules.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../domain/canonical_preview_adapter.dart';

/// Restricted UI preview based on the supplied Blueprint only.
/// Interactions run in memory; this widget never writes to the backend.
class SafePreview extends StatefulWidget {
  const SafePreview({
    super.key,
    required this.blueprint,
    this.simulationRole,
    this.simulationState = 'default',
    this.interactionRules,
  });

  final Map<String, dynamic> blueprint;

  // For simulated preview only, not backend authorization.
  final String? simulationRole;
  final String simulationState;
  final List<Map<String, dynamic>>? interactionRules;
  @override
  State<SafePreview> createState() => _SafePreviewState();
}

class _SafePreviewState extends State<SafePreview> {
  String? screenId;
  String mode = 'mobile';
  String? runtimeState;
  final Map<String, String> inputs = {};
  Map<String, dynamic> obj(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<Map<String, dynamic>> array(String key) {
    final value = adaptCanonicalPreview(widget.blueprint)[key];

    if (value is! List) return [];

    return value.whereType<Map>().map(obj).toList();
  }

  List<Map<String, dynamic>> availableScreens() {
    final seen = <String>{};

    return array('screens').where((screen) {
      final id = screen['screenId'];

      return id is String && id.trim().isNotEmpty && seen.add(id);
    }).toList();
  }

  int componentOrder(dynamic value) {
    if (value is num && value.isFinite) {
      return value.toInt();
    }

    return 0;
  }

  Color primary() {
    final tokens = obj(widget.blueprint['designTokens']);
    final hex = (tokens['primaryColor'] ?? '#6654E8').toString().replaceAll(
      '#',
      '',
    );
    return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFF6654E8);
  }

  Map<String, dynamic> get projectTokens =>
      obj(widget.blueprint['designTokens']);

  String get projectFontFamily {
    final font = projectTokens['fontFamily']?.toString().trim() ?? '';
    return font.isEmpty ? 'Roboto' : font;
  }

  double get projectSpacing {
    final raw = projectTokens['baseSpacing'];
    final number =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

    return number != null && number.isFinite && number >= 4 && number <= 32
        ? number
        : 8;
  }

  double get projectRadius {
    final raw = projectTokens['borderRadius'];
    final number =
        raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

    return number != null && number.isFinite && number >= 0 && number <= 48
        ? number
        : 12;
  }

  double boundedNumber(dynamic raw, double fallback, double min, double max) {
    if (raw is! num || !raw.isFinite || raw < min || raw > max) {
      return fallback;
    }
    return raw.toDouble();
  }

  Color secondary() {
    final raw = (projectTokens['secondaryColor'] ?? '#2C8FCE').toString();
    if (!RegExp(r'^#[A-Fa-f0-9]{6}$').hasMatch(raw)) {
      return const Color(0xFF2C8FCE);
    }
    return Color(int.parse('FF${raw.substring(1)}', radix: 16));
  }

  bool get isProjectDark {
    final value = (projectTokens['mode'] ?? 'light').toString();
    if (value == 'dark') return true;
    if (value == 'system') {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return false;
  }

  void navigate(String id) {
    if (!availableScreens().any((screen) => screen['screenId'] == id)) {
      return;
    }

    setState(() {
      screenId = id;
      inputs.clear();
      runtimeState = null;
    });
  }

  bool executeInteraction(Map<String, dynamic> component, String trigger) {
    final identifiers = <String>{
      for (final key in [
        'componentInstanceId',
        'componentId',
        'templateSourceId',
        'id',
      ])
        if (component[key] != null && component[key].toString().isNotEmpty)
          component[key].toString(),
    };

    final rules = widget.interactionRules ?? array('interactions');

    final matching = rules.where(
      (rule) =>
          identifiers.contains((rule['componentId'] ?? '').toString()) &&
          rule['trigger'] == trigger,
    );

    if (matching.isEmpty) return false;

    for (final rule in matching) {
      switch (rule['action']) {
        case 'navigate':
          final target = (rule['targetScreenId'] ?? '').toString();
          if (array('screens').any((screen) => screen['screenId'] == target)) {
            navigate(target);
          }
          break;

        case 'show-message':
          final message = (rule['message'] ?? '').toString();
          if (message.trim().isNotEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
          break;

        case 'set-state':
          final target = (rule['targetState'] ?? '').toString();
          if (V4VisibilityRules.states.contains(target)) {
            setState(() => runtimeState = target);
          }
          break;
      }
    }

    return true;
  }

  Widget component(
    Map<String, dynamic> c,
    Color accent, {
    List<Widget> children = const [],
  }) {
    final type = (c['type'] ?? '').toString();
    final props = obj(c['props'] ?? c['properties']);
    final text = (props['text'] ?? props['label'] ?? '').toString();
    final label = (props['label'] ?? text).toString();
    switch (type) {
      case 'text':
      case 'header':
        final alignment = switch (props['alignment']) {
          'center' => TextAlign.center,
          'right' => TextAlign.right,
          _ => TextAlign.left,
        };
        return Padding(
          padding: EdgeInsets.symmetric(vertical: projectSpacing),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              text,
              textAlign: alignment,
              style: TextStyle(
                fontSize: boundedNumber(
                  props['fontSize'],
                  type == 'header' || props['variant'] == 'heading' ? 22 : 14,
                  8,
                  96,
                ),
                fontWeight:
                    type == 'header' || props['variant'] == 'heading'
                        ? FontWeight.w900
                        : FontWeight.w500,
                fontFamily: projectFontFamily,
                color: isProjectDark ? Colors.white : const Color(0xFF19213D),
              ),
            ),
          ),
        );

      case 'card':
      case 'section':
      case 'container':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Container(
            key: ValueKey(
              'preview-parent-${c['componentInstanceId'] ?? c['id']}',
            ),
            width: double.infinity,
            padding: EdgeInsets.all(projectSpacing * 2),
            decoration: BoxDecoration(
              color:
                  isProjectDark
                      ? const Color(0xFF2B3345)
                      : const Color(0xFFF6F4FC),
              borderRadius: BorderRadius.circular(projectRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isProjectDark
                              ? Colors.white
                              : const Color(0xFF19213D),
                    ),
                  ),
                ...children,
              ],
            ),
          ),
        );

      case 'button':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed:
                  props['disabled'] == true ||
                          props['enabled'] == false ||
                          (runtimeState ?? widget.simulationState) == 'disabled'
                      ? null
                      : () {
                        if (!executeInteraction(c, 'onClick')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Preview-only action - No backend request was made',
                              ),
                            ),
                          );
                        }
                      },
              child: Text(label.isEmpty ? 'Continue' : label),
            ),
          ),
        );
      case 'input':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: TextField(
            key: ValueKey('preview-input-${screenId ?? ''}-${instanceId(c)}'),
            enabled:
                props['disabled'] != true &&
                props['enabled'] != false &&
                (runtimeState ?? widget.simulationState) != 'disabled',
            onChanged: (v) {
              setState(() {
                inputs[(c['componentInstanceId'] ?? c['id'] ?? '').toString()] =
                    v;
              });
              executeInteraction(c, 'onChange');
            },
            onSubmitted: (_) => executeInteraction(c, 'onSubmit'),
            decoration: InputDecoration(
              labelText: label,
              hintText: (props['placeholder'] ?? 'Enter value').toString(),
            ),
          ),
        );
      case 'list':
      case 'tabs':
        final dense = type == 'list' && props['dense'] == true;
        final values =
            props['items'] is List ? props['items'] as List : const [];
        if (values.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No list data available'),
          );
        }
        return Padding(
          padding: EdgeInsets.all(dense ? 4 : 9),
          child: Wrap(
            spacing: dense ? 4 : 7,
            runSpacing: dense ? 2 : 7,
            children: [
              for (final item in values)
                Chip(
                  visualDensity:
                      dense ? VisualDensity.compact : VisualDensity.standard,
                  label: Text(item.toString()),
                ),
            ],
          ),
        );

      case 'table':
        final striped = props['stripedRows'] == true;
        final values =
            props['items'] is List ? props['items'] as List : const [];
        if (values.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No table data available'),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < values.length; index++)
                Container(
                  padding: const EdgeInsets.all(9),
                  color:
                      striped && index.isOdd
                          ? const Color(0xFFF1EFFB)
                          : Colors.transparent,
                  child: Text(values[index].toString()),
                ),
            ],
          ),
        );

      case 'chart':
        // Render saved Blueprint values only; never generate chart samples.
        final rawValues = props['values'] ?? props['items'];
        final values =
            rawValues is List
                ? rawValues
                    .map<double?>((item) {
                      final raw =
                          item is Map ? (item['value'] ?? item['y']) : item;
                      if (raw is! num) return null;
                      final number = raw.toDouble();
                      return number.isFinite && number >= 0 ? number : null;
                    })
                    .whereType<double>()
                    .take(12)
                    .toList()
                : <double>[];
        if (values.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No chart data available'),
          );
        }
        final maxValue = values.reduce((a, b) => a > b ? a : b);
        return Container(
          height: 110,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.bottomCenter,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in values)
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 28,
                    height:
                        maxValue == 0
                            ? 0.0
                            : (value / maxValue * 90)
                                .clamp(0.0, 90.0)
                                .toDouble(),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      case 'dialog':
        return ListTile(
          leading: Icon(Icons.info_outline, color: accent),
          title: Text(label),
        );
      case 'image':
        final alt = (props['alt'] ?? '').toString();

        // Preview must never contact external image hosts.
        return Semantics(
          image: true,
          label: alt.isEmpty ? 'Image placeholder' : alt,
          child: Container(
            key: const ValueKey('safe-preview-image-placeholder'),
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF1EFFB),
              borderRadius: BorderRadius.circular(projectRadius),
            ),
            child: const Center(
              child: Icon(
                Icons.image_outlined,
                color: AppColors.muted,
                size: 44,
              ),
            ),
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Unsupported component: $type',
            style: const TextStyle(color: Color(0xFFBA435A)),
          ),
        );
    }
  }

  String instanceId(Map<String, dynamic> value) =>
      (value['componentInstanceId'] ?? value['id'] ?? '').toString();

  String parentId(Map<String, dynamic> value) {
    final props = obj(value['props'] ?? value['properties']);
    return (value['parentComponentId'] ?? props['parentComponentId'] ?? '')
        .toString()
        .trim();
  }

  bool isContainer(Map<String, dynamic> value) =>
      const {'card', 'container', 'section'}.contains(value['type']);

  Widget nestedComponent(
    Map<String, dynamic> item,
    Color accent,
    List<Map<String, dynamic>> components,
    Set<String> ancestors,
  ) {
    final props = obj(item['props'] ?? item['properties']);
    final rawVisibility = props['visibility'];

    final visibility =
        rawVisibility is Map
            ? Map<String, dynamic>.from(rawVisibility)
            : rawVisibility == null
            ? null
            : <String, dynamic>{};

    if (!V4VisibilityRules.isVisible(
      rule: visibility,
      userRole: widget.simulationRole,
      uiState: runtimeState ?? widget.simulationState,
      formValues: inputs,
    )) {
      return const SizedBox.shrink();
    }

    final id = instanceId(item);

    if (id.isEmpty || ancestors.contains(id)) {
      return const Text('Invalid nested component reference');
    }

    final path = {...ancestors, id};

    final children =
        components
            .where(
              (candidate) =>
                  parentId(candidate) == id && instanceId(candidate) != id,
            )
            .map(
              (candidate) =>
                  nestedComponent(candidate, accent, components, path),
            )
            .toList();

    return component(item, accent, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final screens = availableScreens();
    if (screens.isEmpty) {
      return const SurfaceCard(child: Text('No screens in blueprint'));
    }
    final selected =
        screens.any((e) => e['screenId'] == screenId)
            ? screenId!
            : screens.first['screenId'].toString();
    final screen = screens.firstWhere((e) => e['screenId'] == selected);
    final components =
        array(
            'componentInstances',
          ).where((c) => c['screenId'] == selected).toList()
          ..sort(
            (a, b) => componentOrder(
              a['order'],
            ).compareTo(componentOrder(b['order'])),
          );
    final ids = components.map(instanceId).toSet();

    final roots =
        components.where((item) {
          final parent = parentId(item);
          if (parent.isEmpty || !ids.contains(parent)) {
            return true;
          }

          final matches = components.where(
            (candidate) => instanceId(candidate) == parent,
          );

          return matches.isEmpty || !isContainer(matches.first);
        }).toList();

    final routes =
        array('routes')
            .where(
              (r) =>
                  r['sourceScreenId'] == selected &&
                  r['enabled'] != false &&
                  screens.any((s) => s['screenId'] == r['targetScreenId']),
            )
            .toList();
    final accent = primary();
    final dark = isProjectDark;
    final foreground = dark ? Colors.white : const Color(0xFF19213D);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SmallLabel(
                'SIMULATED Â· NO LIVE TRANSACTIONS',
                color: AppColors.purple,
              ),
              for (final value in ['mobile', 'tablet', 'web', 'desktop'])
                ChoiceChip(
                  label: Text(value.toUpperCase()),
                  selected: mode == value,
                  onSelected: (_) => setState(() => mode = value),
                ),
            ],
          ),
          if (screens.length > 1) ...[
            const SizedBox(height: 12),
            const Text(
              'Select preview screen',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in screens)
                  ChoiceChip(
                    key: ValueKey('preview-screen-${item['screenId']}'),
                    label: Text('Open ${item['name'] ?? item['screenId']}'),
                    selected: item['screenId'] == selected,
                    onSelected: (_) {
                      navigate(item['screenId'].toString());
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    mode == 'mobile'
                        ? 390
                        : mode == 'web'
                        ? 1000
                        : 790,
              ),
              child: Container(
                width: double.infinity,
                key: const ValueKey('preview-canvas'),
                constraints: const BoxConstraints(minHeight: 320),
                padding: EdgeInsets.all(projectSpacing * 2),
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF1B2130) : Colors.white,
                  borderRadius: BorderRadius.circular(projectRadius),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: .08),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            (screen['name'] ?? 'Screen').toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 27),
                    for (final c in roots.isEmpty ? components : roots)
                      nestedComponent(c, accent, components, <String>{}),
                    const SizedBox(height: 18),
                    if (routes.isNotEmpty)
                      Text(
                        'Preview navigation',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: foreground,
                        ),
                      ),
                    if (routes.isNotEmpty) const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final route in routes)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: secondary(),
                            ),
                            onPressed:
                                () => navigate(
                                  route['targetScreenId'].toString(),
                                ),
                            icon: const Icon(Icons.arrow_forward, size: 15),
                            label: Text(
                              screens
                                      .where(
                                        (s) =>
                                            s['screenId'] ==
                                            route['targetScreenId'],
                                      )
                                      .map((s) => s['name'].toString())
                                      .firstOrNull ??
                                  'Next screen',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Preview-only UI. Actions are simulated locally; no payments, bookings, account changes or network requests are made.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
