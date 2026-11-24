import '../../builder/domain/registry/component_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/workspace_providers.dart';
import '../domain/workspace.dart';
import 'simulated_preview.dart';

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
  String? message;
  Future<void> save(String section, dynamic data) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await ref.read(workspaceRepositoryProvider).save(
          widget.workspace.projectId, section, widget.workspace.version, data);
      ref.invalidate(workspaceProvider(widget.workspace.projectId));
      ref.invalidate(projectValidationProvider(widget.workspace.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$section saved Ã‚Â· next version created')));
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
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
                    'Real server-backed draft editor Ã‚Â· Owner-controlled Ã‚Â· Saved content stays after refresh.',
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
        InlineError(message!)
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
      return '${lookup[row['fromScreenId']] ?? 'Missing source'} Ã¢â€ â€™ ${lookup[row['toScreenId']] ?? 'Missing target'}';
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
    await widget.onSave(widget.section, nextItems);
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
        else ...[
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
  late bool componentEnabled;
  late int componentFontSize;
  late String state;
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
      'trigger'
    ]) {
      fields[key] = TextEditingController(text: (item[key] ?? '').toString());
    }
    priority = (item['priority'] ?? 'Must').toString();
    componentType = (item['type'] ?? 'text').toString();
    final componentProperties = item['properties'];
    componentEnabled =
        componentProperties is Map && componentProperties['enabled'] is bool
            ? componentProperties['enabled'] as bool
            : true;
    final storedFontSize =
        componentProperties is Map ? componentProperties['fontSize'] : null;
    componentFontSize = storedFontSize is num
        ? storedFontSize.round().clamp(8, 96).toInt()
        : 16;
    state = (item['state'] ?? 'default').toString();
    fromId = item['fromScreenId'] as String?;
    toId = item['toScreenId'] as String?;
    screenId = item['screenId'] as String?;
    featureIds = Set<String>.from(item['featureIds'] as List? ?? []);
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
              'Screen', screenId, screens, (v) => setState(() => screenId = v)),
          DropdownButtonFormField<String>(
              initialValue: componentType,
              decoration: const InputDecoration(labelText: 'Component type'),
              items: ComponentRegistry.v4ComponentTypes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => componentType = v ?? 'text')),
          const SizedBox(height: 14),
          input('label', 'Component label', required: true),
          input('text', 'Display text', lines: 2),
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
          if (componentType == 'button')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              subtitle: const Text('Allow button interaction'),
              value: componentEnabled,
              onChanged: (value) => setState(() => componentEnabled = value),
            )
        ]);
        break;
      case _ItemType.interaction:
        resultFields.addAll([
          input('name', 'Rule name', required: true),
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
                'permission-denied'
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => state = v ?? 'default')),
          const SizedBox(height: 14),
          input('description', 'Behavior / validation / recovery', lines: 3)
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
                      'featureIds': featureIds.toList()
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
                    result.addAll({
                      'screenId': screenId,
                      'type': componentType,
                      'label': fields['label']!.text.trim(),
                      'text': fields['text']!.text.trim(),
                      if (componentType == 'text')
                        'properties': {
                          ...?((widget.original?['properties'] is Map)
                              ? Map<String, dynamic>.from(
                                  widget.original!['properties'] as Map)
                              : null),
                          'fontSize': componentFontSize,
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
                      'description': fields['description']!.text.trim()
                    });
                    break;
                }
                if (widget.type == _ItemType.component) {
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
  late String mode;
  @override
  void initState() {
    super.initState();
    final values = widget.workspace.fields('theme');
    primary = TextEditingController(
        text: (values['primaryColor'] ?? '#6654E8').toString());
    secondary = TextEditingController(
        text: (values['secondaryColor'] ?? '#2C8FCE').toString());
    mode = (values['mode'] ?? 'light').toString();
  }

  @override
  void dispose() {
    primary.dispose();
    secondary.dispose();
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
        Wrap(spacing: 20, runSpacing: 18, children: [
          for (final entry in <(String, TextEditingController)>[
            ('Primary color', primary),
            ('Secondary color', secondary)
          ])
            SizedBox(
                width: 240,
                child: Row(children: [
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
                                  : 'Use #RRGGBB')),
                ])),
        ]),
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
              await widget.onSave('theme', {
                'primaryColor': primary.text.trim(),
                'secondaryColor': secondary.text.trim(),
                'mode': mode
              });
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Theme')),
      ])));
}

final projectValidationProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
        (ref, id) => ref.watch(workspaceRepositoryProvider).validate(id));

class _BlueprintEditor extends ConsumerStatefulWidget {
  const _BlueprintEditor({required this.workspace});
  final Workspace workspace;
  @override
  ConsumerState<_BlueprintEditor> createState() => _BlueprintEditorState();
}

class _BlueprintEditorState extends ConsumerState<_BlueprintEditor> {
  bool generating = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final blueprint = widget.workspace.fields('blueprint');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SurfaceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Blueprint & UI Studio',
            subtitle:
                'A deterministic local template generates validated design data, not executable customer code.'),
        const SizedBox(height: 17),
        FilledButton.icon(
            onPressed: generating
                ? null
                : () async {
                    setState(() {
                      generating = true;
                      error = null;
                    });
                    try {
                      final result = await ref
                          .read(workspaceRepositoryProvider)
                          .compile(widget.workspace.projectId,
                              widget.workspace.version);
                      ref.invalidate(
                          workspaceProvider(widget.workspace.projectId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Template Blueprint saved Ã‚Â· v${result['draftVersion']}')));
                      }
                    } catch (e) {
                      if (mounted) setState(() => error = '$e');
                    } finally {
                      if (mounted) setState(() => generating = false);
                    }
                  },
            icon: const Icon(Icons.auto_awesome),
            label: Text(generating
                ? 'CompilingÃ¢â‚¬Â¦'
                : 'Compile & Save Template Blueprint')),
        const SizedBox(height: 8),
        const Text(
            'Requires mapped features and valid routes. Remote AI is intentionally not connected.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        if (error != null) ...[const SizedBox(height: 13), InlineError(error!)],
      ])),
      const SizedBox(height: 15),
      if (blueprint['screens'] is List)
        SafePreview(blueprint: blueprint)
      else
        const SurfaceCard(
            child: Text(
                'No compiled blueprint yet. Add features, screens, and routes; then compile.')),
    ]);
  }
}

class _ValidationEditor extends ConsumerStatefulWidget {
  const _ValidationEditor({required this.workspace});
  final Workspace workspace;
  @override
  ConsumerState<_ValidationEditor> createState() => _ValidationEditorState();
}

class _ValidationEditorState extends ConsumerState<_ValidationEditor> {
  bool exporting = false;
  String? error;
  @override
  Widget build(BuildContext context) =>
      ref.watch(projectValidationProvider(widget.workspace.projectId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => InlineError('$e',
              onRetry: () => ref.invalidate(
                  projectValidationProvider(widget.workspace.projectId))),
          data: (result) {
            final findings = (result['findings'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            return SurfaceCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const SectionTitle('Review & Export',
                      subtitle:
                          'Live deterministic checks Ã‚Â· explicit draft-only handoff; approval service not yet enabled.'),
                  const SizedBox(height: 18),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    SmallLabel('${result['blockers']} blockers',
                        color: (result['blockers'] as int) > 0
                            ? const Color(0xFFCA5161)
                            : AppColors.green),
                    SmallLabel('${result['advisories']} advisories'),
                    SmallLabel('Draft v${result['draftVersion']}'),
                  ]),
                  const SizedBox(height: 15),
                  if (findings.isEmpty)
                    const Text(
                        'No current validation findings for implemented rules.')
                  else ...[
                    for (final finding in findings)
                      ListTile(
                          leading: Icon(
                              finding['severity'] == 'blocker'
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              color: finding['severity'] == 'blocker'
                                  ? const Color(0xFFCA5161)
                                  : AppColors.purple),
                          title:
                              Text((finding['ruleId'] ?? 'Finding').toString()),
                          subtitle: Text((finding['message'] ?? '').toString()))
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                      onPressed: exporting
                          ? null
                          : () async {
                              setState(() {
                                exporting = true;
                                error = null;
                              });
                              try {
                                final bytes = await ref
                                    .read(workspaceRepositoryProvider)
                                    .exportDraft(widget.workspace.projectId);
                                ref.read(downloadPortProvider).saveZip(
                                    'reqviora-${widget.workspace.projectId}-draft-v${widget.workspace.version}.zip',
                                    bytes);
                              } catch (e) {
                                if (mounted) setState(() => error = '$e');
                              } finally {
                                if (mounted) setState(() => exporting = false);
                              }
                            },
                      icon: const Icon(Icons.download_outlined),
                      label: Text(exporting
                          ? 'Preparing ZIPÃ¢â‚¬Â¦'
                          : 'Download Draft 19 + manifest ZIP')),
                  const SizedBox(height: 9),
                  const Text(
                      'DRAFT export only. Not an approved immutable revision or a deployable customer app.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  if (error != null) ...[
                    const SizedBox(height: 13),
                    InlineError(error!)
                  ],
                ]));
          });
}
