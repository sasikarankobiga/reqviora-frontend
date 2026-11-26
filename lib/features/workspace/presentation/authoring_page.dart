import '../../builder/domain/registry/component_registry.dart';
import '../../builder/domain/registry/v4_component_layout.dart';
import '../../builder/domain/registry/v4_interaction_rule_validator.dart';
import '../../builder/domain/registry/v4_visibility_rules.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/workspace_providers.dart';
import '../domain/workspace.dart';
import '../domain/navigation_diagnostics.dart';
import '../domain/draft_conflict.dart';
import '../domain/feature_coverage.dart';
import '../domain/screen_access_roles.dart';
import '../domain/builder_quality_checks.dart';
import '../domain/theme_accessibility.dart';
import '../domain/theme_draft_tokens.dart';
import 'simulated_preview.dart';
import 'v4_blueprint_selection_panel.dart';
import 'v4_blueprint_property_inspector.dart';
import '../domain/local_preview_blueprint.dart';
import '../domain/v4_blueprint_history.dart';

/// Service-backed authoring for Builder steps 02-08. All writes are owner-scoped
/// and carry a draft version. No fake AI/approval states are produced here.
class BuilderAuthoringPage extends ConsumerWidget {
  const BuilderAuthoringPage(
      {super.key, required this.projectId, required this.step});
  final String projectId;
  final int step;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(workspaceProvider(projectId)).when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator())),
            error: (e, _) => InlineError('$e',
                onRetry: () => ref.invalidate(workspaceProvider(projectId))),
            data: (workspace) => _Content(
                key: ValueKey('$projectId-$step-${workspace.version}'),
                workspace: workspace,
                step: step),
          );
}

class _Content extends ConsumerStatefulWidget {
  const _Content({super.key, required this.workspace, required this.step});
  final Workspace workspace;
  final int step;
  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  bool busy = false;
  bool conflict = false;
  String? message;
  Future<void> save(String section, dynamic data) async {
    setState(() {
      busy = true;
      message = null;
      conflict = false;
    });
    try {
      await ref.read(workspaceRepositoryProvider).save(
          widget.workspace.projectId, section, widget.workspace.version, data);
      ref.invalidate(workspaceProvider(widget.workspace.projectId));
      ref.invalidate(projectValidationProvider(widget.workspace.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$section saved ┬╖ next version created')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          conflict = isDraftConflict(e);
          message = draftConflictMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    final n = widget.step;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SurfaceCard(
          color: Color(0xFFF3F0FF),
          padding: EdgeInsets.all(15),
          child: Row(children: [
            Icon(Icons.save_as_outlined, color: AppColors.purple),
            SizedBox(width: 12),
            Expanded(
                child: Text(
                    'Real server-backed draft editor ┬╖ Owner-controlled ┬╖ Saved content stays after refresh.',
                    style: TextStyle(fontSize: 12, height: 1.45)))
          ])),
      const SizedBox(height: 16),
      if (n == 2) ...[
        _ItemEditor(
            workspace: w,
            section: 'features',
            title: 'Feature catalogue',
            icon: Icons.auto_awesome_motion,
            type: _ItemType.feature,
            onSave: save),
        const SizedBox(height: 18),
        _ItemEditor(
            workspace: w,
            section: 'screens',
            title: 'Screens & feature mapping',
            icon: Icons.grid_view_rounded,
            type: _ItemType.screen,
            onSave: save),
      ] else if (n == 3)
        _ItemEditor(
            workspace: w,
            section: 'routes',
            title: 'Navigation connections',
            icon: Icons.hub_outlined,
            type: _ItemType.route,
            onSave: save)
      else if (n == 4)
        _ThemeEditor(workspace: w, onSave: save)
      else if (n == 5)
        V4ComponentsStudio(workspace: w, onSave: save)
      else if (n == 6)
        _ItemEditor(
            workspace: w,
            section: 'interactions',
            title: 'Interaction & state rules',
            icon: Icons.tune_rounded,
            type: _ItemType.interaction,
            onSave: save)
      else if (n == 7)
        _BlueprintEditor(workspace: w)
      else if (n == 8)
        _ValidationEditor(workspace: w),
      if (message != null) ...[
        const SizedBox(height: 15),
        Semantics(
          liveRegion: true,
          child: InlineError(
            message!,
            onRetry: conflict
                ? () {
                    setState(() {
                      conflict = false;
                      message = null;
                    });
                    ref.invalidate(
                      workspaceProvider(widget.workspace.projectId),
                    );
                  }
                : null,
          ),
        )
      ],
      if (busy) const LinearProgressIndicator(),
      const SizedBox(height: 24),
      Wrap(spacing: 9, runSpacing: 9, children: [
        OutlinedButton.icon(
            onPressed: () =>
                context.go('/projects/${w.projectId}/builder/${n - 1}'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous')),
        if (n < 8)
          FilledButton.icon(
              onPressed: () =>
                  context.go('/projects/${w.projectId}/builder/${n + 1}'),
              icon: const Icon(Icons.arrow_forward),
              label: Text('Continue to Step ${n + 1}')),
      ]),
    ]);
  }
}

/// Testable Screen Editor entry point for Builder Step 02.
class V4ScreensStudio extends StatelessWidget {
  const V4ScreensStudio({
    super.key,
    required this.workspace,
    required this.onSave,
  });

  final Workspace workspace;
  final Future<void> Function(String section, dynamic data) onSave;

  @override
  Widget build(BuildContext context) => _ItemEditor(
        workspace: workspace,
        section: 'screens',
        title: 'Screens & feature mapping',
        icon: Icons.grid_view_rounded,
        type: _ItemType.screen,
        onSave: onSave,
      );
}
/// Testable entry point for the original V4 Components Studio.
class V4ComponentsStudio extends StatelessWidget {
  const V4ComponentsStudio({
    super.key,
    required this.workspace,
    required this.onSave,
  });

  final Workspace workspace;
  final Future<void> Function(String section, dynamic data) onSave;

  @override
  Widget build(BuildContext context) {
    return _ItemEditor(
      workspace: workspace,
      section: 'components',
      title: 'Components Studio',
      icon: Icons.widgets_outlined,
      type: _ItemType.component,
      onSave: onSave,
    );
  }
}

/// Testable entry point for V4 Step 06.
class V4InteractionsStudio extends StatelessWidget {
  const V4InteractionsStudio({
    super.key,
    required this.workspace,
    required this.onSave,
  });

  final Workspace workspace;
  final Future<void> Function(String section, dynamic data) onSave;

  @override
  Widget build(BuildContext context) {
    return _ItemEditor(
      workspace: workspace,
      section: 'interactions',
      title: 'Interaction & state rules',
      icon: Icons.tune_rounded,
      type: _ItemType.interaction,
      onSave: onSave,
    );
  }
}

enum _ItemType { feature, screen, route, component, interaction }

class _ItemEditor extends StatefulWidget {
  const _ItemEditor(
      {required this.workspace,
      required this.section,
      required this.title,
      required this.icon,
      required this.type,
      required this.onSave});
  final Workspace workspace;
  final String section;
  final String title;
  final IconData icon;
  final _ItemType type;
  final Future<void> Function(String, dynamic) onSave;
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late List<Map<String, dynamic>> items;
  @override
  void initState() {
    super.initState();
    items = widget.workspace.items(widget.section);
  }

  String itemTitle(Map<String, dynamic> row) => (row['name'] ??
          row['label'] ??
          row['type'] ??
          row['trigger'] ??
          'Untitled')
      .toString();
  String itemDescription(Map<String, dynamic> row) {
    if (widget.type == _ItemType.route) {
      final lookup = {
        for (final s in widget.workspace.items('screens')) s['id']: s['name']
      };
      return '${lookup[row['fromScreenId']] ?? 'Missing source'} ΓåÆ ${lookup[row['toScreenId']] ?? 'Missing target'}';
    }
    return (row['description'] ??
            row['purpose'] ??
            row['text'] ??
            row['state'] ??
            '')
        .toString();
  }

  Future<void> edit([Map<String, dynamic>? existing]) async {
    final updated = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _ItemDialog(
            type: widget.type,
            original: existing,
            workspace: widget.workspace));
    if (updated == null) return;
    if (widget.type == _ItemType.component) {
      final idError = ComponentRegistry.validateV4ComponentId(
        id: (updated['id'] ?? '').toString(),
        existingIds: items.map((item) => (item['id'] ?? '').toString()),
        editingId: existing?['id']?.toString(),
      );

      if (idError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(idError)),
        );
        return;
      }
    }
    final nextItems = <Map<String, dynamic>>[
      for (final item in items)
        if (existing != null && item['id'] == existing['id']) updated else item,
      if (existing == null) updated,
    ];
    if (widget.type == _ItemType.component) {
      final error = V4ComponentLayout.validate(nextItems);

      if (error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
    }
    await widget.onSave(widget.section, nextItems);
  }

  Future<void> reuseComponent(Map<String, dynamic> source) async {
    final screens = widget.workspace.items('screens');

    if (screens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a screen first')),
      );
      return;
    }

    String? targetScreenId = source['screenId']?.toString();

    final selectedScreen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AlertDialog(
          title: const Text('Reuse component on screen'),
          content: DropdownButtonFormField<String>(
            initialValue: screens.any(
              (screen) => screen['id'] == targetScreenId,
            )
                ? targetScreenId
                : null,
            decoration: const InputDecoration(
              labelText: 'Target screen',
            ),
            isExpanded: true,
            items: [
              for (final screen in screens)
                DropdownMenuItem<String>(
                  value: screen['id'].toString(),
                  child: Text(
                    (screen['name'] ?? screen['id']).toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => updateDialog(() => targetScreenId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: targetScreenId == null
                  ? null
                  : () => Navigator.pop(dialogContext, targetScreenId),
              child: const Text('Reuse'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selectedScreen == null) return;

    final clone = V4ComponentLayout.cloneForReuse(
      source: source,
      newId: const Uuid().v4(),
      targetScreenId: selectedScreen,
    );

    final updatedItems = <Map<String, dynamic>>[
      ...items,
      clone,
    ];

    final error = V4ComponentLayout.validate(updatedItems);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    await widget.onSave(widget.section, updatedItems);
  }

  Future<void> reorderComponents(int oldIndex, int newIndex) async {
    if (widget.type != _ItemType.component) return;

    if (oldIndex < 0 || oldIndex >= items.length) return;

    if (newIndex < 0 || newIndex >= items.length) return;
    if (oldIndex == newIndex) return;

    final reordered = List<Map<String, dynamic>>.from(items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    // Persist first; keep the existing order if saving fails.
    await widget.onSave(widget.section, reordered);

    if (!mounted) return;
    setState(() {
      items = reordered;
    });
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Remove this item?'),
                content: const Text(
                    'Linked screens/routes/components may become invalid. Validation will flag dependencies.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Remove'))
                ]));
    if (yes != true) return;
    if (widget.type == _ItemType.component) {
      final hasChildren = items.any(
        (child) => child['parentComponentId'] == item['id'],
      );

      if (hasChildren) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remove or reassign child components first'),
          ),
        );
        return;
      }
    }
    final nextItems = <Map<String, dynamic>>[
      for (final existing in items)
        if (existing['id'] != item['id']) existing,
    ];
    await widget.onSave(widget.section, nextItems);
  }

  @override
  Widget build(BuildContext context) => SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(widget.icon, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(
              child: Text(widget.title,
                  style: Theme.of(context).textTheme.titleLarge)),
          FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Add'))
        ]),
        const SizedBox(height: 16),
        if (widget.type == _ItemType.feature) ...[
          Builder(
            builder: (context) {
              final duplicates = BuilderQualityChecks.duplicateNames(items);
              return duplicates.isEmpty
                  ? const SizedBox.shrink()
                  : Text('Duplicate feature names: ${duplicates.join(', ')}');
            },
          ),
        ],
        if (widget.type == _ItemType.screen) ...[
          Builder(
            builder: (context) {
              final coverage = FeatureCoverage.calculate(
                widget.workspace.items('features'),
                items,
              );

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feature coverage: ${coverage.mappedFeatures}/${coverage.totalFeatures} mapped',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (coverage.unmappedFeatureNames.isNotEmpty)
                      Text(
                        'Unmapped features: ${coverage.unmappedFeatureNames.join(', ')}',
                      ),
                    if (coverage.screensWithoutFeatures > 0)
                      Text(
                        'Screens without feature mappings: ${coverage.screensWithoutFeatures}',
                      ),
                    if (coverage.invalidFeatureReferences > 0)
                      Text(
                        'Invalid feature references: ${coverage.invalidFeatureReferences}',
                      ),
                    if (BuilderQualityChecks.duplicateNames(items).isNotEmpty)
                      Text(
                        'Duplicate screen names: ${BuilderQualityChecks.duplicateNames(items).join(', ')}',
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        if (widget.type == _ItemType.route) ...[
          Builder(
            builder: (context) {
              final screens = widget.workspace.items('screens');
              final diagnostics = NavigationDiagnostics.inspect(
                screens,
                items,
              );
              final unreachable =
                  BuilderQualityChecks.unreachableFromEntry(screens, items);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Navigation diagnostics',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('Broken routes: ${diagnostics.brokenRoutes}'),
                    Text('Duplicate routes: ${diagnostics.duplicateRoutes}'),
                    Text(
                      'Disconnected screens: '
                      '${diagnostics.disconnectedScreenNames.isEmpty ? 'None' : diagnostics.disconnectedScreenNames.join(', ')}',
                    ),
                    if (screens.isNotEmpty)
                      Text(
                        'Unreachable from first screen (assumed entry): '
                        '${unreachable.isEmpty ? 'None' : unreachable.join(', ')}',
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
        if (items.isEmpty)
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FD),
                  borderRadius: BorderRadius.circular(14)),
              child: const Column(children: [
                Icon(Icons.layers_outlined, color: AppColors.muted, size: 28),
                SizedBox(height: 8),
                Text('No items yet. Add your first item to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted))
              ]))
        else if (widget.type == _ItemType.component) ...[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            onReorderItem: reorderComponents,
            itemBuilder: (context, index) {
              final row = items[index];
              return Padding(
                key: ValueKey(row['id']),
                padding: const EdgeInsets.only(bottom: 9),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      itemTitle(row),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      itemDescription(row),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Reuse',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => reuseComponent(row),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => edit(row),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => remove(row),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ] else ...[
          for (final row in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                      title: Text(itemTitle(row),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(itemDescription(row),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Wrap(spacing: 2, children: [
                        IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => edit(row)),
                        IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => remove(row)),
                      ]))),
            )
        ],
      ]));
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog(
      {required this.type, required this.original, required this.workspace});
  final _ItemType type;
  final Map<String, dynamic>? original;
  final Workspace workspace;
  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  late String priority;
  late String componentType;
  String visibilityMode = 'always';
  String visibilityState = 'default';
  late bool componentEnabled;
  late bool componentRequired;
  late int componentFontSize;
  late int componentElevation;
  late int componentPadding;
  late String componentHeaderAlignment;
  late bool componentListDense;
  late bool componentTableStriped;
  String? parentComponentId;
  late String state;
  String? interactionComponentId;
  String? interactionTrigger;
  String interactionAction = 'navigate';
  String? interactionTargetScreenId;
  String interactionTargetState = 'default';
  String? fromId;
  String? toId;
  String? screenId;
  late Set<String> featureIds;
  @override
  void initState() {
    super.initState();
    final item = widget.original ?? {};
    for (final key in [
      'name',
      'description',
      'purpose',
      'label',
      'text',
      'trigger',
      'message',
      'visibilityRole',
      'visibilityFieldId',
      'visibilityEquals'
    ]) {
      fields[key] = TextEditingController(text: (item[key] ?? '').toString());
    }
    priority = (item['priority'] ?? 'Must').toString();
    componentType = (item['type'] ?? 'text').toString();
    final componentProperties = item['properties'];
    final existingVisibility =
        componentProperties is Map ? componentProperties['visibility'] : null;
    final visibility = existingVisibility is Map
        ? Map<String, dynamic>.from(existingVisibility)
        : <String, dynamic>{};
    visibilityMode = V4VisibilityRules.modes.contains(
      visibility['mode'],
    )
        ? visibility['mode'].toString()
        : 'always';
    visibilityState = V4VisibilityRules.states.contains(
      visibility['state'],
    )
        ? visibility['state'].toString()
        : 'default';
    fields['visibilityRole']!.text = (visibility['role'] ?? '').toString();
    fields['visibilityFieldId']!.text =
        (visibility['fieldId'] ?? '').toString();
    fields['visibilityEquals']!.text = (visibility['equals'] ?? '').toString();
    componentRequired =
        componentProperties is Map && componentProperties['required'] == true;
    final storedPlaceholder =
        componentProperties is Map ? componentProperties['placeholder'] : null;
    fields['placeholder'] = TextEditingController(
      text: storedPlaceholder is String ? storedPlaceholder : 'Enter text',
    );
    componentEnabled =
        componentProperties is Map && componentProperties['enabled'] is bool
            ? componentProperties['enabled'] as bool
            : true;
    final storedFontSize =
        componentProperties is Map ? componentProperties['fontSize'] : null;
    componentFontSize = storedFontSize is num
        ? storedFontSize.round().clamp(8, 96).toInt()
        : 16;
    final storedElevation =
        componentProperties is Map ? componentProperties['elevation'] : null;
    componentElevation = storedElevation is num
        ? storedElevation.round().clamp(0, 24).toInt()
        : 2;
    final storedPadding =
        componentProperties is Map ? componentProperties['padding'] : null;
    componentPadding =
        storedPadding is num ? storedPadding.round().clamp(0, 64).toInt() : 16;
    final storedImageSource =
        componentProperties is Map ? componentProperties['src'] : null;
    final storedImageAlt =
        componentProperties is Map ? componentProperties['alt'] : null;

    fields['imageSource'] = TextEditingController(
      text: storedImageSource is String ? storedImageSource : '',
    );
    fields['imageAlt'] = TextEditingController(
      text: storedImageAlt is String ? storedImageAlt : '',
    );

    final storedAlignment =
        componentProperties is Map ? componentProperties['alignment'] : null;
    componentHeaderAlignment =
        ['left', 'center', 'right'].contains(storedAlignment)
            ? storedAlignment as String
            : 'left';

    componentListDense =
        componentProperties is Map && componentProperties['dense'] == true;

    componentTableStriped = componentProperties is Map &&
        componentProperties['stripedRows'] == true;

    state = (item['state'] ?? 'default').toString();
    interactionComponentId = item['componentId']?.toString();
    interactionTrigger = item['trigger']?.toString();
    interactionAction = item['action']?.toString() ?? 'navigate';
    interactionTargetScreenId = item['targetScreenId']?.toString();
    interactionTargetState = item['targetState']?.toString() ?? 'default';
    fromId = item['fromScreenId'] as String?;
    toId = item['toScreenId'] as String?;
    screenId = item['screenId'] as String?;
    parentComponentId = item['parentComponentId']?.toString();
    featureIds = Set<String>.from(item['featureIds'] as List? ?? []);
    fields['accessRoles'] = TextEditingController(
      text: (item['accessRoles'] is List)
          ? (item['accessRoles'] as List).map((role) => role.toString()).join(', ')
          : '',
    );
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget input(String key, String label,
          {bool required = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: TextFormField(
              controller: fields[key],
              maxLines: lines,
              decoration: InputDecoration(labelText: label),
              validator: required
                  ? (s) => s == null || s.trim().isEmpty
                      ? '$label is required'
                      : null
                  : null));
  Widget selector(String label, String? value, List<Map<String, dynamic>> items,
          ValueChanged<String?> onChange) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              initialValue: items.any((e) => e['id'] == value) ? value : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                for (final s in items)
                  DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                          (s['name'] ?? s['label'] ?? 'Untitled').toString(),
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: onChange,
              validator: (v) => v == null ? 'Select $label' : null));
  @override
  Widget build(BuildContext context) {
    final screens = widget.workspace.items('screens');
    final features = widget.workspace.items('features');
    final interactionComponents = widget.workspace
        .items('components')
        .where((component) => V4InteractionRuleValidator.componentTriggers
            .containsKey(component['type']))
        .toList();
    final resultFields = <Widget>[];
    switch (widget.type) {
      case _ItemType.feature:
        resultFields.addAll([
          input('name', 'Feature name', required: true),
          input('description', 'Description', lines: 3),
          DropdownButtonFormField<String>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: ['Must', 'Should', 'Could', "Won't"]
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => priority = v ?? 'Must'))
        ]);
        break;
      case _ItemType.screen:
        resultFields.addAll([
          input('name', 'Screen name', required: true),
          input('purpose', 'Screen purpose', lines: 2),
          const SizedBox(height: 8),
          input('accessRoles', 'Access roles (comma-separated)'),
          const Text(
            'Leave empty for all roles. Example: Admin, Manager',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          const Text('Map features to this screen',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          if (features.isEmpty)
            const Text('Add features first',
                style: TextStyle(color: AppColors.muted)),
          Wrap(spacing: 7, children: [
            for (final f in features)
              FilterChip(
                  label: Text((f['name'] ?? 'Unnamed').toString()),
                  selected: featureIds.contains(f['id']),
                  onSelected: (selected) => setState(() => selected
                      ? featureIds.add(f['id'] as String)
                      : featureIds.remove(f['id'])))
          ]),
        ]);
        break;
      case _ItemType.route:
        resultFields.addAll([
          selector('From screen', fromId, screens,
              (v) => setState(() => fromId = v)),
          selector('To screen', toId, screens, (v) => setState(() => toId = v)),
          input('trigger', 'Trigger (e.g. tap)', required: true)
        ]);
        break;
      case _ItemType.component:
        resultFields.addAll([
          selector(
              'Screen',
              screenId,
              screens,
              (v) => setState(() {
                    screenId = v;
                    parentComponentId = null;
                  })),
          DropdownButtonFormField<String>(
              initialValue: componentType,
              decoration: const InputDecoration(labelText: 'Component type'),
              items: ComponentRegistry.v4ComponentTypes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => componentType = v ?? 'text')),
          const SizedBox(height: 14),
          input('label', 'Component label', required: true),
          Builder(
            builder: (context) {
              final parents = widget.workspace
                  .items('components')
                  .where((item) =>
                      V4ComponentLayout.parentTypes.contains(item['type']) &&
                      item['screenId'] == screenId &&
                      item['id'] != widget.original?['id'])
                  .toList();

              final validParent = parents.any(
                (item) => item['id'] == parentComponentId,
              )
                  ? parentComponentId
                  : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('parent-$screenId-$validParent'),
                  initialValue: validParent ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Parent component',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('None (top level)'),
                    ),
                    for (final parent in parents)
                      DropdownMenuItem<String>(
                        value: parent['id'].toString(),
                        child: Text(
                          (parent['label'] ?? parent['id']).toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    parentComponentId =
                        value == null || value.isEmpty ? null : value;
                  }),
                ),
              );
            },
          ),
          input('text', 'Display text', lines: 2),
          if (componentType == 'input') ...[
            input('placeholder', 'Placeholder'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              subtitle: const Text('Require a value for this input'),
              value: componentRequired,
              onChanged: (value) => setState(() => componentRequired = value),
            ),
          ],
          if (componentType == 'text')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Font Size: $componentFontSize'),
                Slider(
                  value: componentFontSize.toDouble(),
                  min: 8,
                  max: 96,
                  divisions: 88,
                  label: '$componentFontSize',
                  onChanged: (value) =>
                      setState(() => componentFontSize = value.round()),
                ),
              ],
            ),
          if (componentType == 'card' ||
              componentType == 'container' ||
              componentType == 'section')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Padding: $componentPadding'),
                Slider(
                  value: componentPadding.toDouble(),
                  min: 0,
                  max: 64,
                  divisions: 64,
                  label: '$componentPadding',
                  onChanged: (value) =>
                      setState(() => componentPadding = value.round()),
                ),
              ],
            ),
          if (componentType == 'card')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Elevation: $componentElevation'),
                Slider(
                  value: componentElevation.toDouble(),
                  min: 0,
                  max: 24,
                  divisions: 24,
                  label: '$componentElevation',
                  onChanged: (value) =>
                      setState(() => componentElevation = value.round()),
                ),
              ],
            ),
          if (componentType == 'image') ...[
            input('imageSource', 'Image URL'),
            input('imageAlt', 'Alt text'),
          ],
          if (componentType == 'header')
            DropdownButtonFormField<String>(
              key: ValueKey('header-alignment-$componentHeaderAlignment'),
              initialValue: componentHeaderAlignment,
              decoration: const InputDecoration(
                labelText: 'Header alignment',
              ),
              items: const [
                DropdownMenuItem(value: 'left', child: Text('Left')),
                DropdownMenuItem(value: 'center', child: Text('Center')),
                DropdownMenuItem(value: 'right', child: Text('Right')),
              ],
              onChanged: (value) => setState(
                () => componentHeaderAlignment = value ?? 'left',
              ),
            ),
          if (componentType == 'list')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dense layout'),
              value: componentListDense,
              onChanged: (value) => setState(() => componentListDense = value),
            ),
          if (componentType == 'table')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Striped rows'),
              value: componentTableStriped,
              onChanged: (value) =>
                  setState(() => componentTableStriped = value),
            ),
          if (componentType == 'button')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              subtitle: const Text('Allow button interaction'),
              value: componentEnabled,
              onChanged: (value) => setState(() => componentEnabled = value),
            ),
          const Divider(height: 30),
          const Text(
            'Conditional Visibility',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('visibility-mode-selector'),
            initialValue: visibilityMode,
            decoration: const InputDecoration(
              labelText: 'Visibility Condition',
            ),
            items: const [
              DropdownMenuItem(value: 'always', child: Text('Always visible')),
              DropdownMenuItem(value: 'role', child: Text('User role')),
              DropdownMenuItem(value: 'state', child: Text('UI state')),
              DropdownMenuItem(
                value: 'fieldEquals',
                child: Text('Form field equals value'),
              ),
            ],
            onChanged: (value) => setState(
              () => visibilityMode = value ?? 'always',
            ),
          ),
          const SizedBox(height: 12),
          if (visibilityMode == 'role')
            input('visibilityRole', 'Required User Role', required: true),
          if (visibilityMode == 'state')
            DropdownButtonFormField<String>(
              key: const ValueKey('visibility-state-selector'),
              initialValue: visibilityState,
              decoration: const InputDecoration(
                labelText: 'Required UI State',
              ),
              items: [
                for (final value in V4VisibilityRules.states)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
              ],
              onChanged: (value) => setState(
                () => visibilityState = value ?? 'default',
              ),
            ),
          if (visibilityMode == 'fieldEquals') ...[
            input('visibilityFieldId', 'Form Field ID', required: true),
            input('visibilityEquals', 'Expected Value', required: true),
          ],
        ]);
        break;
      case _ItemType.interaction:
        final selectedComponent = interactionComponents.where(
          (component) => component['id'] == interactionComponentId,
        );

        final selectedType = selectedComponent.isEmpty
            ? ''
            : selectedComponent.first['type'].toString();

        final availableTriggers =
            V4InteractionRuleValidator.componentTriggers[selectedType] ??
                <String>{};

        resultFields.addAll([
          input('name', 'Rule name', required: true),
          if (interactionComponents.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('interaction-source-component'),
              initialValue: interactionComponents.any(
                (component) => component['id'] == interactionComponentId,
              )
                  ? interactionComponentId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Source Component',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('None - state-only rule'),
                ),
                for (final component in interactionComponents)
                  DropdownMenuItem<String>(
                    value: component['id'].toString(),
                    child: Text(
                      (component['label'] ??
                              component['name'] ??
                              component['id'])
                          .toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                interactionComponentId =
                    value == null || value.isEmpty ? null : value;
                interactionTrigger = null;
              }),
            ),
            const SizedBox(height: 14),
            if (interactionComponentId != null) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'interaction-trigger-$interactionComponentId',
                ),
                initialValue: availableTriggers.contains(interactionTrigger)
                    ? interactionTrigger
                    : null,
                decoration: const InputDecoration(labelText: 'Trigger'),
                items: [
                  for (final trigger in availableTriggers)
                    DropdownMenuItem(
                      value: trigger,
                      child: Text(trigger),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => interactionTrigger = value),
                validator: (value) => value == null ? 'Select Trigger' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: V4InteractionRuleValidator.actions.contains(
                  interactionAction,
                )
                    ? interactionAction
                    : 'navigate',
                decoration: const InputDecoration(labelText: 'Action'),
                items: [
                  for (final action in [
                    'navigate',
                    'show-message',
                    'set-state',
                  ])
                    DropdownMenuItem(
                      value: action,
                      child: Text(action),
                    ),
                ],
                onChanged: (value) => setState(
                  () => interactionAction = value ?? 'navigate',
                ),
              ),
              const SizedBox(height: 14),
              if (interactionAction == 'navigate')
                selector(
                  'Destination Screen',
                  interactionTargetScreenId,
                  screens,
                  (value) => setState(
                    () => interactionTargetScreenId = value,
                  ),
                ),
              if (interactionAction == 'show-message')
                input('message', 'Message text', required: true),
              if (interactionAction == 'set-state')
                DropdownButtonFormField<String>(
                  initialValue: interactionTargetState,
                  decoration: const InputDecoration(
                    labelText: 'Target UI State',
                  ),
                  items: [
                    for (final target in [
                      'default',
                      'loading',
                      'empty',
                      'error',
                      'success',
                      'disabled',
                      'permission-denied',
                    ])
                      DropdownMenuItem(
                        value: target,
                        child: Text(target),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => interactionTargetState = value ?? 'default',
                  ),
                ),
              const SizedBox(height: 14),
            ],
          ],
          DropdownButtonFormField<String>(
            initialValue: state,
            decoration: const InputDecoration(labelText: 'UI State'),
            items: [
              'default',
              'loading',
              'empty',
              'error',
              'success',
              'disabled',
              'permission-denied',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => state = v ?? 'default'),
          ),
          const SizedBox(height: 14),
          input('description', 'Behavior / validation / recovery', lines: 3),
        ]);
        break;
    }
    return AlertDialog(
        title: Text(
            '${widget.original == null ? 'Add' : 'Edit'} ${widget.type.name}'),
        content: SizedBox(
            width: 490,
            child: SingleChildScrollView(
                child: Form(
                    key: formKey,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: resultFields)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final result = <String, dynamic>{
                  ...?widget.original,
                  'id': widget.original?['id'] ?? const Uuid().v4()
                };
                switch (widget.type) {
                  case _ItemType.feature:
                    result.addAll({
                      'name': fields['name']!.text.trim(),
                      'description': fields['description']!.text.trim(),
                      'priority': priority,
                      'status': 'confirmed',
                      'source': 'manual-owner'
                    });
                    break;
                  case _ItemType.screen:
                    result.addAll({
                      'name': fields['name']!.text.trim(),
                      'purpose': fields['purpose']!.text.trim(),
                      'required': true,
                      'featureIds': featureIds.toList(),
                      'accessRoles': parseScreenAccessRoles(fields['accessRoles']!.text)
                    });
                    break;
                  case _ItemType.route:
                    result.addAll({
                      'fromScreenId': fromId,
                      'toScreenId': toId,
                      'trigger': fields['trigger']!.text.trim(),
                      'name': 'Route'
                    });
                    break;
                  case _ItemType.component:
                    result.remove('parentComponentId');
                    result.addAll({
                      'screenId': screenId,
                      if (parentComponentId != null)
                        'parentComponentId': parentComponentId,
                      'type': componentType,
                      'label': fields['label']!.text.trim(),
                      'text': fields['text']!.text.trim(),
                      if (componentType == 'input')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'placeholder': fields['placeholder']!.text.trim(),
                          'required': componentRequired,
                        },
                      if (componentType == 'text')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'fontSize': componentFontSize,
                        },
                      if (componentType == 'card')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'elevation': componentElevation,
                          'padding': componentPadding,
                        },
                      if (componentType == 'container' ||
                          componentType == 'section')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'padding': componentPadding,
                        },
                      if (componentType == 'image')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'src': fields['imageSource']!.text.trim(),
                          'alt': fields['imageAlt']!.text.trim(),
                        },
                      if (componentType == 'header')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'alignment': componentHeaderAlignment,
                        },
                      if (componentType == 'list')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'dense': componentListDense,
                        },
                      if (componentType == 'table')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'stripedRows': componentTableStriped,
                        },
                      if (componentType == 'button')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'enabled': componentEnabled,
                        }
                    });
                    break;
                  case _ItemType.interaction:
                    result.addAll({
                      'name': fields['name']!.text.trim(),
                      'state': state,
                      'description': fields['description']!.text.trim(),
                    });

                    if (interactionComponentId != null) {
                      result.addAll({
                        'componentId': interactionComponentId,
                        'trigger': interactionTrigger,
                        'action': interactionAction,
                      });

                      result.remove('targetScreenId');
                      result.remove('message');
                      result.remove('targetState');

                      if (interactionAction == 'navigate') {
                        result['targetScreenId'] = interactionTargetScreenId;
                      } else if (interactionAction == 'show-message') {
                        result['message'] = fields['message']!.text.trim();
                      } else if (interactionAction == 'set-state') {
                        result['targetState'] = interactionTargetState;
                      }

                      final error = V4InteractionRuleValidator.validate(
                        rule: result,
                        components: widget.workspace.items('components'),
                        screens: widget.workspace.items('screens'),
                      );

                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        return;
                      }
                    } else {
                      // Existing state-only rules remain supported.
                      result.remove('componentId');
                      result.remove('trigger');
                      result.remove('action');
                      result.remove('targetScreenId');
                      result.remove('message');
                      result.remove('targetState');
                    }
                    break;
                }
                if (widget.type == _ItemType.component) {
                  final visibility = <String, dynamic>{
                    'mode': visibilityMode,
                    if (visibilityMode == 'role')
                      'role': fields['visibilityRole']!.text.trim(),
                    if (visibilityMode == 'state') 'state': visibilityState,
                    if (visibilityMode == 'fieldEquals') ...{
                      'fieldId': fields['visibilityFieldId']!.text.trim(),
                      'equals': fields['visibilityEquals']!.text.trim(),
                    },
                  };

                  final visibilityError =
                      V4VisibilityRules.validate(visibility);

                  if (visibilityError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(visibilityError)),
                    );
                    return;
                  }

                  final currentProperties = result['properties'];
                  final mergedProperties = currentProperties is Map
                      ? Map<String, dynamic>.from(currentProperties)
                      : <String, dynamic>{};

                  if (visibilityMode == 'always') {
                    mergedProperties.remove('visibility');
                  } else {
                    mergedProperties['visibility'] = visibility;
                  }

                  result['properties'] = mergedProperties;
                  final error = ComponentRegistry.validateV4Component(
                    type: componentType,
                    label: fields['label']!.text,
                    screenId: screenId,
                    validScreenIds: widget.workspace
                        .items('screens')
                        .map((screen) => screen['id'].toString()),
                  );

                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                    return;
                  }
                }
                Navigator.pop(context, result);
              },
              child: const Text('Save'))
        ]);
  }
}

class _ThemeEditor extends StatefulWidget {
  const _ThemeEditor({required this.workspace, required this.onSave});
  final Workspace workspace;
  final Future<void> Function(String, dynamic) onSave;
  @override
  State<_ThemeEditor> createState() => _ThemeEditorState();
}

class _ThemeEditorState extends State<_ThemeEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController primary;
  late final TextEditingController secondary;
  late final TextEditingController fontFamily;
  late final TextEditingController baseSpacing;
  late final TextEditingController borderRadius;
  late String mode;
  @override
  void initState() {
    super.initState();
    final values = widget.workspace.fields('theme');
    primary = TextEditingController(
        text: (values['primaryColor'] ?? '#6654E8').toString());
    secondary = TextEditingController(
        text: (values['secondaryColor'] ?? '#2C8FCE').toString());
    fontFamily = TextEditingController(
        text: (values['fontFamily'] ?? 'Roboto').toString());
    baseSpacing = TextEditingController(
        text: (values['baseSpacing'] ?? 8).toString());
    borderRadius = TextEditingController(
        text: (values['borderRadius'] ?? 12).toString());
    mode = (values['mode'] ?? 'light').toString();
  }

  @override
  void dispose() {
    primary.dispose();
    secondary.dispose();
    fontFamily.dispose();
    baseSpacing.dispose();
    borderRadius.dispose();
    super.dispose();
  }

  Color swatch(String value) => Color(
      int.tryParse('FF${value.replaceAll('#', '')}', radix: 16) ?? 0xFF6654E8);
  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Brand & theme',
            subtitle:
                'Persistent design tokens used by the template renderer.'),
        const SizedBox(height: 20),
        Wrap(
          spacing: 20,
          runSpacing: 18,
          children: [
            for (final entry in <(String, TextEditingController)>[
              ('Primary color', primary),
              ('Secondary color', secondary)
            ])
              SizedBox(
                width: 240,
                child: Row(
                  children: [
                    Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: swatch(entry.$2.text),
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: entry.$2,
                        decoration: InputDecoration(labelText: entry.$1),
                        onChanged: (_) => setState(() {}),
                        validator: (s) =>
                            RegExp(r'^#[A-Fa-f0-9]{6}$').hasMatch(s ?? '')
                                ? null
                                : 'Use #RRGGBB',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Builder(
          builder: (context) {
            final color = primary.text.trim();
            final valid = RegExp(r'^#[A-Fa-f0-9]{6}$').hasMatch(color);

            if (!valid) {
              return const Text(
                'Enter a valid primary color to check contrast.',
              );
            }

            final ratio = contrastRatio(color, '#FFFFFF');
            final passes = meetsNormalTextContrast(color, '#FFFFFF');

            return Text(
              'Primary color on white: ${ratio.toStringAsFixed(2)}:1 ΓÇö '
              '${passes ? 'WCAG AA normal-text contrast passed' : 'Low contrast: use a darker primary color'}',
              style: TextStyle(
                color:
                    passes ? const Color(0xFF16734C) : const Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        Builder(
          builder: (context) {
            final color = secondary.text.trim();
            if (!RegExp(r'^#[A-Fa-f0-9]{6}$').hasMatch(color)) {
              return const Text(
                'Enter a valid secondary color to check contrast.',
              );
            }

            final ratio = contrastRatio(color, '#FFFFFF');
            final passes = meetsNormalTextContrast(color, '#FFFFFF');

            return Text(
              'Secondary color on white: ${ratio.toStringAsFixed(2)}:1 ΓÇö '
              '${passes ? 'WCAG AA normal-text contrast passed' : 'Low contrast: use a darker secondary color'}',
            );
          },
        ),
        const SizedBox(height: 17),
        const SizedBox(height: 20),
        const SectionTitle(
          'Typography & layout',
          subtitle: 'Project-level design tokens for the generated UI.',
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: fontFamily,
          decoration: const InputDecoration(
            labelText: 'Font family',
            hintText: 'Roboto',
          ),
          validator: (value) =>
              (value ?? '').trim().isEmpty
                  ? 'Enter a font family'
                  : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: baseSpacing,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Base spacing (px)',
            hintText: '8',
          ),
          validator: (value) {
            final number = int.tryParse((value ?? '').trim());
            return number != null && number >= 4 && number <= 32
                ? null
                : 'Use a whole number from 4 to 32';
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: borderRadius,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Border radius (px)',
            hintText: '12',
          ),
          validator: (value) {
            final number = int.tryParse((value ?? '').trim());
            return number != null && number >= 0 && number <= 48
                ? null
                : 'Use a whole number from 0 to 48';
          },
        ),
        const SizedBox(height: 17),
        DropdownButtonFormField<String>(
            initialValue: mode,
            decoration: const InputDecoration(labelText: 'Color mode'),
            items: ['light', 'dark', 'system']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => mode = v ?? 'light')),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: () async {
              if (!(form.currentState?.validate() ?? false)) return;
              await widget.onSave(
                'theme',
                buildThemeDraftTokens(
                  existing: widget.workspace.fields('theme'),
                  primaryColor: primary.text.trim(),
                  secondaryColor: secondary.text.trim(),
                  mode: mode,
                  fontFamily: fontFamily.text.trim(),
                  baseSpacing: int.parse(baseSpacing.text.trim()),
                  borderRadius: int.parse(borderRadius.text.trim()),
                ),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Theme')),
      ])));
}

final projectValidationProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, id) => ref.watch(workspaceRepositoryProvider).validate(id));

/// Testable Step 07 Blueprint studio.
class V4BlueprintStudio extends StatelessWidget {
  const V4BlueprintStudio({
    super.key,
    required this.workspace,
  });

  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    return _BlueprintEditor(workspace: workspace);
  }
}

class _BlueprintEditor extends ConsumerStatefulWidget {
  const _BlueprintEditor({required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_BlueprintEditor> createState() => _BlueprintEditorState();
}

class _BlueprintEditorState extends ConsumerState<_BlueprintEditor> {
  bool generating = false;
  bool savingDraft = false;
  bool autosaveEnabled = false;
  Timer? _autosaveTimer;

  void scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (!autosaveEnabled || draftBlueprint == null) return;

    _autosaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !savingDraft && !generating) {
        saveBlueprintDraft();
      }
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
  String? error;
  String? selectedBlueprintComponentId;
  Map<String, dynamic>? draftBlueprint;
  Map<String, dynamic>? localPreview;
  V4BlueprintHistory? blueprintHistory;
  int inspectorRevision = 0;

  void undoBlueprint() {
    if (savingDraft) return;
    final restored = blueprintHistory?.undo();
    if (restored == null) return;

    setState(() {
      draftBlueprint = restored;
      inspectorRevision++;
    });
    scheduleAutosave();
  }

  void redoBlueprint() {
    if (savingDraft) return;
    final restored = blueprintHistory?.redo();
    if (restored == null) return;

    setState(() {
      draftBlueprint = restored;
      inspectorRevision++;
    });
    scheduleAutosave();
  }

  Map<String, dynamic>? selectedComponent(Map<String, dynamic> blueprint) {
    final selectedId = selectedBlueprintComponentId;
    if (selectedId == null) return null;

    final components = blueprint['componentInstances'];
    if (components is! List) return null;

    for (final raw in components) {
      if (raw is! Map) continue;
      final component = Map<String, dynamic>.from(raw);
      final id = (component['componentInstanceId'] ?? component['id'] ?? '')
          .toString();
      if (id == selectedId) return component;
    }
    return null;
  }

  // Edits are local preview-only. Never represent them as saved or approved.
  void updateDraftComponent(Map<String, dynamic> blueprint, Map<String, dynamic> updated) {
    if (savingDraft) return;
    final id =
        (updated['componentInstanceId'] ?? updated['id'] ?? '').toString();
    if (id.isEmpty || id != selectedBlueprintComponentId) return;

    final rawComponents = blueprint['componentInstances'];
    if (rawComponents is! List) return;

    var found = false;
    final components = rawComponents.map((raw) {
      if (raw is! Map) return raw;
      final component = Map<String, dynamic>.from(raw);
      final currentId =
          (component['componentInstanceId'] ?? component['id'] ?? '')
              .toString();
      if (currentId != id) return raw;
      found = true;
      return Map<String, dynamic>.from(updated);
    }).toList();
    if (!found) return;

    final nextBlueprint = Map<String, dynamic>.from(blueprint);
    nextBlueprint['componentInstances'] = components;
    final history = blueprintHistory ??=
        V4BlueprintHistory(widget.workspace.fields('blueprint'));

    if (!history.record(nextBlueprint)) return;

    setState(() {
      draftBlueprint = history.current;
    });
    scheduleAutosave();
  }

  Future<void> saveBlueprintDraft() async {
    final nextBlueprint = draftBlueprint;
    if (nextBlueprint == null || savingDraft || generating) return;

    _autosaveTimer?.cancel();

    setState(() {
      savingDraft = true;
      error = null;
    });

    try {
      final version = await ref.read(workspaceRepositoryProvider).save(
        widget.workspace.projectId,
        'blueprint',
        widget.workspace.version,
        nextBlueprint,
      );

      if (!mounted) return;

      setState(() {
        draftBlueprint = null;
        blueprintHistory = null;
        selectedBlueprintComponentId = null;
        inspectorRevision++;
      });

      ref.invalidate(workspaceProvider(widget.workspace.projectId));
      ref.invalidate(projectValidationProvider(widget.workspace.projectId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blueprint draft saved - v$version (not approved)'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Blueprint draft was not saved: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => savingDraft = false);
      }
    }
  }

  void generatePreview() {
    try {
      // Derived from server-loaded Workspace content, not hardcoded DB records.
      final preview = buildLocalPreviewBlueprint(widget.workspace);
      setState(() {
        localPreview = preview;
        draftBlueprint = preview;
        blueprintHistory = V4BlueprintHistory(preview);
        selectedBlueprintComponentId = null;
        inspectorRevision++;
        error = null;
      });
      scheduleAutosave();
    } catch (e) {
      setState(() {
        localPreview = null;
        error = e.toString();
      });
    }
  }

  Future<void> compileBlueprint() async {
    _autosaveTimer?.cancel();
    setState(() {
      generating = true;
      error = null;
    });
    try {
      final response = await ref.read(workspaceRepositoryProvider).compile(
            widget.workspace.projectId,
            widget.workspace.version,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated draft saved - v${response['draftVersion']}',
          ),
        ),
      );
      setState(() {
        // Only compiled server state is authoritative after a successful save.
        draftBlueprint = null;
        selectedBlueprintComponentId = null;
        blueprintHistory = null;
        inspectorRevision++;
      });
      ref.invalidate(projectValidationProvider(widget.workspace.projectId));
      ref.invalidate(workspaceProvider(widget.workspace.projectId));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedBlueprint = widget.workspace.fields('blueprint');
    final visibleBlueprint = draftBlueprint ?? savedBlueprint;
    final hasCompiledBlueprint = visibleBlueprint['screens'] is List;
    final interactionRules = widget.workspace.items('interactions');

    if (hasCompiledBlueprint) {
      blueprintHistory ??= V4BlueprintHistory(savedBlueprint);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                'Blueprint & UI Studio',
                subtitle:
                    'Preview server-loaded Builder data or compile a Blueprint through the backend.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilterChip(
                    key: const ValueKey('step07-autosave-toggle'),
                    label: const Text('Autosave (2s)'),
                    selected: autosaveEnabled,
                    onSelected: savingDraft || generating
                        ? null
                        : (enabled) {
                            setState(() => autosaveEnabled = enabled);
                            if (enabled) {
                              scheduleAutosave();
                            } else {
                              _autosaveTimer?.cancel();
                            }
                          },
                  ),
                  OutlinedButton.icon(
                    onPressed: generating ? null : generatePreview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Generate Local Preview'),
                  ),
                  if (draftBlueprint != null)
                    FilledButton.icon(
                      key: const ValueKey('step07-save-draft-button'),
                      onPressed: savingDraft || generating
                          ? null
                          : saveBlueprintDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        savingDraft ? 'Saving Draft...' : 'Save Blueprint Draft',
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: generating || savingDraft || draftBlueprint != null ? null : compileBlueprint,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      generating
                          ? 'Compiling...'
                          : 'Generate & Save Blueprint Draft',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Generate a local draft, edit it, then save using Save Blueprint Draft. '
                'Local generation saves through the Backend Draft API. Server compilation and approval remain separate.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                InlineError(error!),
              ],
            ],
          ),
        ),
        if (localPreview != null && draftBlueprint == null) ...[
          const SizedBox(height: 16),
          const SectionTitle('Local simulation - not validated'),
          const SizedBox(height: 8),
          SafePreview(
            key: ObjectKey(localPreview),
            blueprint: localPreview!,
            interactionRules: interactionRules,
          ),
        ],
        const SizedBox(height: 16),
        const SectionTitle('Blueprint Workspace'),
        const SizedBox(height: 8),
        if (hasCompiledBlueprint) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('step07-undo-button'),
                onPressed:
                    blueprintHistory?.canUndo == true ? undoBlueprint : null,
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('step07-redo-button'),
                onPressed:
                    blueprintHistory?.canRedo == true ? redoBlueprint : null,
                icon: const Icon(Icons.redo),
                label: const Text('Redo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: V4BlueprintSelectionPanel(
              blueprint: visibleBlueprint,
              selectedComponentId: selectedBlueprintComponentId,
              onSelected: (id) {
                setState(() => selectedBlueprintComponentId = id);
              },
            ),
          ),
          if (selectedBlueprintComponentId != null) ...[
            const SizedBox(height: 12),
            SurfaceCard(
              child: V4BlueprintPropertyInspector(
                key: ValueKey(
                  'step07-inspector-$inspectorRevision-$selectedBlueprintComponentId',
                ),
                component: selectedComponent(visibleBlueprint),
                onChanged: (updated) {
                  updateDraftComponent(visibleBlueprint, updated);
                },
              ),
            ),
          ],
          if (draftBlueprint != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Unsaved local preview changes - Backend not updated',
              key: ValueKey('step07-unsaved-notice'),
            ),
          ],
          const SizedBox(height: 12),
          SafePreview(
            blueprint: visibleBlueprint,
            interactionRules: interactionRules,
          ),
        ] else
          const SurfaceCard(
            child: Text(
              'No Blueprint draft yet. Add screens and components, then generate a local preview.',
            ),
          ),
      ],
    );
  }
}

class _ValidationEditor extends ConsumerStatefulWidget {
  const _ValidationEditor({required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<_ValidationEditor> createState() => _ValidationEditorState();
}

class _ValidationEditorState extends ConsumerState<_ValidationEditor> {
  bool validating = false;
  bool exporting = false;
  bool approving = false;
  String? approvedRevisionId;
  Map<String, dynamic>? result;
  String? error;

  Future<void> runValidation() async {
    setState(() {
      validating = true;
      error = null;
      result = null;
    });
    try {
      final response = await ref
          .read(workspaceRepositoryProvider)
          .validate(widget.workspace.projectId);
      if (mounted) setState(() => result = response);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => validating = false);
    }
  }

  Future<void> exportOfficialRevision() async {
    final revisionId = approvedRevisionId;

    if (revisionId == null ||
        revisionId.isEmpty ||
        exporting ||
        approving ||
        validating) {
      return;
    }

    setState(() {
      exporting = true;
      error = null;
    });

    try {
      final repository = ref.read(workspaceRepositoryProvider);

      final metadata = await repository.createOfficialExport(
        widget.workspace.projectId,
        revisionId,
      );

      final exportId = metadata['exportId'];

      if (exportId is! String || exportId.isEmpty) {
        throw StateError('Backend returned no official export ID.');
      }

      final bytes = await repository.downloadOfficialExport(
        widget.workspace.projectId,
        exportId,
      );

      if (bytes.length < 4 ||
          bytes[0] != 80 ||
          bytes[1] != 75 ||
          !((bytes[2] == 3 && bytes[3] == 4) ||
            (bytes[2] == 5 && bytes[3] == 6) ||
            (bytes[2] == 7 && bytes[3] == 8))) {
        throw StateError('Backend did not return a valid ZIP header.');
      }

      if (!mounted) return;

      ref.read(downloadPortProvider).saveZip(
        'reqviora-${widget.workspace.projectId}-$revisionId.zip',
        bytes,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => exporting = false);
      }
    }
  }

  Future<void> approveValidated() async {
    final validation = result;

    if (validation?['passed'] != true ||
        validation?['id'] is! String ||
        (validation!['id'] as String).isEmpty ||
        approving ||
        approvedRevisionId != null) {
      return;
    }

    final validationId = validation['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve Blueprint revision?'),
        content: const Text(
          'Approval creates an immutable revision of the validated draft. '
          'Confirm only after reviewing the design and validation findings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      approving = true;
      error = null;
    });

    try {
      final approved = await ref
          .read(workspaceRepositoryProvider)
          .approveValidatedDraft(
            widget.workspace.projectId,
            widget.workspace.version,
            validationId,
          );

      final revisionId = approved['revisionId'];

      if (revisionId is! String || revisionId.isEmpty) {
        throw StateError('Backend returned no approved revision ID.');
      }

      if (mounted) {
        setState(() => approvedRevisionId = revisionId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) setState(() => approving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final current = result;
    final findings = (current?['findings'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final blockers = current?['blockers'];
    final advisories = current?['advisories'];
    final hasValidation = current != null;
    final backendPassed = current?['passed'];
    final validationId = current?['id'];
    final hasBlockers = backendPassed == false ||
        (backendPassed == null && blockers is num && blockers > 0);
    final validationReady = backendPassed == true ||
        (backendPassed == null &&
            hasValidation &&
            blockers is num &&
            blockers == 0);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            'Review & Validation',
            subtitle: 'Run backend validation for the saved draft.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: validating || exporting || approving || approvedRevisionId != null ? null : runValidation,
            icon: const Icon(Icons.fact_check_outlined),
            label:
                Text(validating ? 'Validating...' : 'Run Backend Validation'),
          ),
          const SizedBox(height: 12),
          if (validating)
            const LinearProgressIndicator()
          else if (current == null)
            const Text('Validation has not been completed.')
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (backendPassed is bool)
                  SmallLabel(
                    backendPassed
                        ? 'Backend validation passed'
                        : 'Backend validation failed',
                    color: backendPassed
                        ? AppColors.green
                        : const Color(0xFFCA5161),
                  ),
                if (blockers is int)
                  SmallLabel('$blockers blockers',
                      color: blockers > 0
                          ? const Color(0xFFCA5161)
                          : AppColors.green),
                if (advisories is int) SmallLabel('$advisories advisories'),
                if (current['draftVersion'] != null)
                  SmallLabel("Draft v${current['draftVersion']}"),
              ],
            ),
            const SizedBox(height: 12),
            if (hasBlockers)
              const Text(
                'Validation blocked: resolve all blockers before approval.',
                key: ValueKey('step08-validation-blocked'),
              )
            else if (validationReady)
              const Text(
                'Validation returned zero blockers. Approval is still required.',
                key: ValueKey('step08-validation-ready'),
              )
            else
              const Text(
                'Validation result is incomplete. Approval readiness is unknown.',
                key: ValueKey('step08-validation-incomplete'),
              ),
            const SizedBox(height: 12),
            if (findings.isEmpty)
              const Text(
                  'No validation findings returned for implemented rules.'),
            for (final finding in findings)
              ListTile(
                leading: Icon(
                  finding['severity'] == 'blocker'
                      ? Icons.error_outline
                      : Icons.info_outline,
                  color: finding['severity'] == 'blocker'
                      ? const Color(0xFFCA5161)
                      : AppColors.purple,
                ),
                title: Text((finding['ruleId'] ?? finding['code'] ?? 'Finding')
                    .toString()),
                subtitle: Text((finding['message'] ?? '').toString()),
              ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('step08-approve-button'),
            onPressed: backendPassed == true &&
                    validationId is String &&
                    validationId.isNotEmpty &&
                    !validating &&
                    !approving &&
                    approvedRevisionId == null
                ? approveValidated
                : null,
            icon: const Icon(Icons.verified_outlined),
            label: Text(approving ? 'Approving...' : 'Approve Revision'),
          ),
          if (approvedRevisionId != null) ...[
            const SizedBox(height: 12),
            Text(
              'Approved revision: $approvedRevisionId',
              key: const ValueKey('step08-approved-revision'),
            ),
          ],
          if (approving) const LinearProgressIndicator(),          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            approvedRevisionId == null
                ? 'Official ZIP export requires a successfully approved revision.'
                : 'Download the official ZIP for the approved revision.',
            key: const ValueKey('step08-export-unavailable'),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('step08-export-disabled'),
            onPressed: approvedRevisionId != null &&
                    !validating &&
                    !approving &&
                    !exporting
                ? exportOfficialRevision
                : null,
            icon: const Icon(Icons.download_outlined),
            label: Text(
              exporting ? 'Preparing Official ZIP...' : 'Download Official ZIP',
            ),
          ),
          if (exporting) const LinearProgressIndicator(),
          if (error != null) ...[
            const SizedBox(height: 12),
            InlineError(error!),
          ],
        ],
      ),
    );
  }
}
