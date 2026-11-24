import 'package:flutter/material.dart';
import '../../builder/domain/registry/v4_visibility_rules.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';

/// Restricted UI renderer. Only known, typed component labels and mock
/// in-memory navigation are supported; never evaluates generated code.
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
  List<Map<String, dynamic>> array(String key) =>
      (widget.blueprint[key] as List? ?? []).map((e) => obj(e)).toList();
  Color primary() {
    final tokens = obj(widget.blueprint['designTokens']);
    final hex =
        (tokens['primaryColor'] ?? '#6654E8').toString().replaceAll('#', '');
    return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFF6654E8);
  }

  void navigate(String id) => setState(() {
        screenId = id;
        inputs.clear();
      });
  bool executeInteraction(
    Map<String, dynamic> component,
    String trigger,
  ) {
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

    final matching = rules.where((rule) =>
        identifiers.contains((rule['componentId'] ?? '').toString()) &&
        rule['trigger'] == trigger);

    if (matching.isEmpty) return false;

    for (final rule in matching) {
      switch (rule['action']) {
        case 'navigate':
          final target = (rule['targetScreenId'] ?? '').toString();
          if (array('screens').any(
            (screen) => screen['screenId'] == target,
          )) {
            navigate(target);
          }
          break;

        case 'show-message':
          final message = (rule['message'] ?? '').toString();
          if (message.trim().isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              text,
              textAlign: type == 'header' ? alignment : TextAlign.left,
              style: TextStyle(
                fontSize:
                    type == 'header' || props['variant'] == 'heading' ? 22 : 14,
                fontWeight: type == 'header' || props['variant'] == 'heading'
                    ? FontWeight.w900
                    : FontWeight.w500,
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4FC),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text.isNotEmpty)
                  Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                    onPressed: () {
                      if (!executeInteraction(c, 'onClick')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Mock action only · No live transaction executed',
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(label.isEmpty ? 'Continue' : label))));
      case 'input':
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: TextField(
                onChanged: (v) {
                  setState(() {
                    inputs[(c['componentInstanceId'] ?? c['id'] ?? '')
                        .toString()] = v;
                  });
                  executeInteraction(c, 'onChange');
                },
                onSubmitted: (_) => executeInteraction(c, 'onSubmit'),
                decoration: InputDecoration(
                    labelText: label,
                    hintText:
                        (props['placeholder'] ?? 'Enter value').toString())));
      case 'list':
      case 'tabs':
        final dense = type == 'list' && props['dense'] == true;
        final values =
            props['items'] as List? ?? ['Item 1', 'Item 2', 'Item 3'];
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
            props['items'] as List? ?? ['Item 1', 'Item 2', 'Item 3'];
        return Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < values.length; index++)
                Container(
                  padding: const EdgeInsets.all(9),
                  color: striped && index.isOdd
                      ? const Color(0xFFF1EFFB)
                      : Colors.transparent,
                  child: Text(values[index].toString()),
                ),
            ],
          ),
        );

      case 'chart':
        return Container(
            height: 110,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.bottomCenter,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in [35.0, 72, 55, 90, 63])
                    Container(
                        width: 28,
                        height: h.toDouble(),
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: .7),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7))))
                ]));
      case 'dialog':
        return ListTile(
            leading: Icon(Icons.info_outline, color: accent),
            title: Text(label));
      case 'image':
        final src = (props['src'] ?? '').toString().trim();
        final alt = (props['alt'] ?? '').toString();
        final uri = Uri.tryParse(src);
        final validUrl = uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty;

        Widget placeholder() => Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.muted,
                  size: 44,
                ),
              ),
            );

        if (!validUrl) {
          return placeholder();
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            src,
            height: 130,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: alt.isEmpty ? null : alt,
            errorBuilder: (context, error, stackTrace) => Semantics(
              label: 'Preview image unavailable',
              child: placeholder(),
            ),
          ),
        );

      default:
        return Container(
            padding: const EdgeInsets.all(12),
            child: Text('Unsupported component: $type',
                style: const TextStyle(color: Color(0xFFBA435A))));
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

    final visibility = rawVisibility is Map
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

    final children = components
        .where(
          (candidate) =>
              parentId(candidate) == id && instanceId(candidate) != id,
        )
        .map(
          (candidate) => nestedComponent(candidate, accent, components, path),
        )
        .toList();

    return component(item, accent, children: children);
  }

  @override
  Widget build(BuildContext context) {
    final screens = array('screens');
    if (screens.isEmpty) {
      return const SurfaceCard(
        child: Text('No screens in blueprint'),
      );
    }
    final selected = screens.any((e) => e['screenId'] == screenId)
        ? screenId!
        : screens.first['screenId'].toString();
    final screen = screens.firstWhere((e) => e['screenId'] == selected);
    final components = array('componentInstances')
        .where((c) => c['screenId'] == selected)
        .toList()
      ..sort((a, b) => ((a['order'] as num?)?.toInt() ?? 0)
          .compareTo((b['order'] as num?)?.toInt() ?? 0));
    final ids = components.map(instanceId).toSet();

    final roots = components.where((item) {
      final parent = parentId(item);
      if (parent.isEmpty || !ids.contains(parent)) {
        return true;
      }

      final matches = components.where(
        (candidate) => instanceId(candidate) == parent,
      );

      return matches.isEmpty || !isContainer(matches.first);
    }).toList();

    final routes = array('routes')
        .where((r) => r['sourceScreenId'] == selected && r['enabled'] != false)
        .toList();
    final accent = primary();
    return SurfaceCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const SmallLabel('SIMULATED · NO LIVE TRANSACTIONS',
                color: AppColors.purple),
            for (final value in ['mobile', 'web', 'desktop'])
              ChoiceChip(
                  label: Text(value.toUpperCase()),
                  selected: mode == value,
                  onSelected: (_) => setState(() => mode = value))
          ]),
      const SizedBox(height: 18),
      Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: mode == 'mobile'
                      ? 390
                      : mode == 'web'
                          ? 1000
                          : 790),
              child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 320),
                  padding: const EdgeInsets.all(21),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withValues(alpha: .08),
                            blurRadius: 18)
                      ]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.auto_awesome, color: accent),
                          const SizedBox(width: 10),
                          Text((screen['name'] ?? 'Screen').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 17))
                        ]),
                        const Divider(height: 27),
                        for (final c in roots.isEmpty ? components : roots)
                          nestedComponent(c, accent, components, <String>{}),
                        const SizedBox(height: 18),
                        if (routes.isNotEmpty)
                          const Text('Mock navigation',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        if (routes.isNotEmpty) const SizedBox(height: 9),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final route in routes)
                            OutlinedButton.icon(
                                onPressed: () => navigate(
                                    route['targetScreenId'].toString()),
                                icon: const Icon(Icons.arrow_forward, size: 15),
                                label: Text(screens
                                        .where((s) =>
                                            s['screenId'] ==
                                            route['targetScreenId'])
                                        .map((s) => s['name'].toString())
                                        .firstOrNull ??
                                    'Next screen')),
                        ]),
                      ])))),
      const SizedBox(height: 16),
      const Text(
          'Preview is a schema-driven approximation. Payment, booking, account and network actions are mocked.',
          style: TextStyle(fontSize: 11, color: AppColors.muted)),
    ]));
  }
}
