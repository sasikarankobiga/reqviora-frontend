import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'v4_blueprint_property_inspector.dart';
import 'v4_blueprint_selection_panel.dart';
import '../domain/v4_blueprint_history.dart';
import 'dart:async';
import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../../projects/data/project_members_repository.dart';
import '../../projects/presentation/project_members_access.dart';
import '../domain/project_edit_policy.dart';
import '../domain/screen_access_roles.dart';
import '../../builder/domain/registry/v4_visibility_rules.dart';
import '../../builder/domain/registry/v4_interaction_rule_validator.dart';
import '../../builder/domain/registry/v4_component_layout.dart';
import 'navigation_graph_editor.dart';
import '../../../core/network/api_client.dart';
import '../domain/zip_archive_check.dart';
import '../../builder/domain/registry/component_registry.dart';
import 'package:flutter/material.dart';
import '../../second_brain/presentation/widgets/second_brain_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../application/workspace_providers.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace.dart';
import '../domain/blueprint_recovery_store.dart';
import '../domain/approved_revision_session.dart';
import '../domain/navigation_diagnostics.dart';
import '../domain/draft_conflict.dart';
import '../domain/feature_coverage.dart';
import '../domain/builder_quality_checks.dart';
import '../domain/theme_accessibility.dart';
import '../domain/theme_draft_tokens.dart';
import 'simulated_preview.dart';
import '../domain/local_preview_blueprint.dart';
import '../domain/backend_blueprint_mapper.dart';

/// Service-backed authoring for Builder steps 02-08. All writes are owner-scoped
/// and carry a draft version. No fake AI/approval states are produced here.
final builderMemberRoleProvider = FutureProvider.autoDispose
    .family<ProjectMemberRole?, String>((ref, projectId) async {
      final actorId = projectMemberActorId(authSession.token);

      if (actorId == null) return null;

      final members = await ref
          .watch(projectMembersRepositoryProvider)
          .getMembers(projectId);

      for (final member in members) {
        if (member.userId.toLowerCase() == actorId.toLowerCase()) {
          return member.role;
        }
      }

      return null;
    });

class _ReadOnlyBuilder extends StatelessWidget {
  const _ReadOnlyBuilder({
    required this.workspace,
    required this.step,
    required this.reason,
  });

  final Workspace workspace;
  final int step;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final visual = workspace.fields('visualEditorDraft');
    final canonical = workspace.fields('blueprint');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LocalizedSectionTitle('Read-only workspace'),
              const SizedBox(height: 12),
              Text(reason),
              const SizedBox(height: 12),
              Text('Project: ${workspace.projectName}'),
              Text('Draft version: ${workspace.version}'),
              Text('Features: ${workspace.items('features').length}'),
              Text('Screens: ${workspace.items('screens').length}'),
              Text('Components: ${workspace.items('components').length}'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed:
                    () =>
                        context.go('/projects/${workspace.projectId}/overview'),
                icon: const Icon(Icons.arrow_back),
                label: const LocalizedUiText('Project overview'),
              ),
              if (step < 8)
                OutlinedButton(
                  onPressed:
                      () => context.go(
                        '/projects/${workspace.projectId}/builder/${step + 1}',
                      ),
                  child: const LocalizedUiText('Next step'),
                ),
            ],
          ),
        ),
        if (visual['screens'] is List) ...[
          const SizedBox(height: 16),
          const LocalizedSectionTitle('Saved visual draft'),
          SafePreview(
            blueprint: visual,
            interactionRules: workspace.items('interactions'),
          ),
        ] else if (canonical['screens'] is List) ...[
          const SizedBox(height: 16),
          const LocalizedSectionTitle('Canonical Blueprint'),
          SafePreview(blueprint: canonical),
        ],
      ],
    );
  }
}

class BuilderAuthoringPage extends ConsumerWidget {
  const BuilderAuthoringPage({
    super.key,
    required this.projectId,
    required this.step,
  });

  final String projectId;
  final int step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (step < 2 || step > 8) {
      return const InlineError('Unsupported Builder step.');
    }

    final role =
        isLocalDemo
            ? const AsyncData<ProjectMemberRole?>(ProjectMemberRole.owner)
            : ref.watch(builderMemberRoleProvider(projectId));

    return role.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) => InlineError(
            'Unable to verify project permissions.',
            onRetry: () => ref.invalidate(builderMemberRoleProvider(projectId)),
          ),
      data: (memberRole) {
        if (memberRole == null) {
          return const InlineError('Project membership could not be verified.');
        }

        return ref
            .watch(workspaceProvider(projectId))
            .when(
              loading:
                  () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error:
                  (error, stack) => InlineError(
                    '$error',
                    onRetry: () => ref.invalidate(workspaceProvider(projectId)),
                  ),
              data: (workspace) {
                final policy = ProjectEditPolicy(
                  role: memberRole,
                  approved: workspace.isApproved,
                );

                if (!policy.canEditStep(step) &&
                    !(step == 8 && policy.canAccessReviewHistory)) {
                  return _ReadOnlyBuilder(
                    workspace: workspace,
                    step: step,
                    reason:
                        workspace.isApproved
                            ? 'This draft is approved and cannot be edited.'
                            : 'Your project role does not allow editing this step.',
                  );
                }

                return _Content(
                  key: ValueKey(
                    step == 7
                        ? '$projectId-$step'
                        : '$projectId-$step-${workspace.version}',
                  ),
                  workspace: workspace,
                  step: step,
                  role: memberRole,
                );
              },
            );
      },
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({
    super.key,
    required this.workspace,
    required this.step,
    required this.role,
  });
  final Workspace workspace;
  final int step;
  final ProjectMemberRole role;
  @override
  ConsumerState<_Content> createState() => _ContentState();
}

class _ContentState extends ConsumerState<_Content> {
  bool busy = false;
  bool conflict = false;
  String? message;
  Future<void> save(String section, dynamic data) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      conflict = false;
    });
    try {
      await ref
          .read(workspaceRepositoryProvider)
          .save(
            widget.workspace.projectId,
            section,
            widget.workspace.version,
            data,
            expectedSectionData: widget.workspace.sections[section],
          );
      ref.invalidate(workspaceProvider(widget.workspace.projectId));
      ref.invalidate(projectValidationProvider(widget.workspace.projectId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$section saved · next version created')),
        );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SurfaceCard(
          color: Color(0xFFF3F0FF),
          padding: EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(Icons.save_as_outlined, color: AppColors.purple),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Real server-backed draft editor · Role-controlled · Saved content stays after refresh.',
                  style: TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (n == 2) ...[
          _ItemEditor(
            workspace: w,
            section: 'features',
            title: 'Feature catalogue',
            icon: Icons.auto_awesome_motion,
            type: _ItemType.feature,
            onSave: save,
          ),
          const SizedBox(height: 18),
          _ItemEditor(
            workspace: w,
            section: 'screens',
            title: 'Screens & feature mapping',
            icon: Icons.grid_view_rounded,
            type: _ItemType.screen,
            onSave: save,
          ),
        ] else if (n == 3)
          _ItemEditor(
            workspace: w,
            section: 'routes',
            title: 'Navigation connections',
            icon: Icons.hub_outlined,
            type: _ItemType.route,
            onSave: save,
          )
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
            onSave: save,
          )
        else if (n == 7)
          _BlueprintEditor(workspace: w)
        else if (n == 8)
          _ValidationEditor(workspace: w, role: widget.role),
        if (message != null) ...[
          const SizedBox(height: 15),
          Semantics(
            liveRegion: true,
            child: InlineError(
              message!,
              onRetry:
                  conflict
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
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        const SizedBox(height: 24),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            OutlinedButton.icon(
              onPressed:
                  busy
                      ? null
                      : () => context.go(
                        '/projects/${w.projectId}/builder/${n - 1}',
                      ),
              icon: const Icon(Icons.arrow_back),
              label: const LocalizedUiText('Previous'),
            ),
            if (n < 8)
              FilledButton.icon(
                onPressed:
                    busy
                        ? null
                        : () => context.go(
                          '/projects/${w.projectId}/builder/${n + 1}',
                        ),
                icon: const Icon(Icons.arrow_forward),
                label: Text('Continue to Step ${n + 1}'),
              ),
          ],
        ),
      ],
    );
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
  const _ItemEditor({
    required this.workspace,
    required this.section,
    required this.title,
    required this.icon,
    required this.type,
    required this.onSave,
  });
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

  String itemTitle(Map<String, dynamic> row) =>
      (row['name'] ??
              row['label'] ??
              row['type'] ??
              row['trigger'] ??
              'Untitled')
          .toString();
  String itemDescription(Map<String, dynamic> row) {
    if (widget.type == _ItemType.route) {
      final lookup = {
        for (final s in widget.workspace.items('screens')) s['id']: s['name'],
      };
      return '${lookup[row['fromScreenId']] ?? 'Missing source'} → ${lookup[row['toScreenId']] ?? 'Missing target'}';
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
      builder:
          (_) => _ItemDialog(
            type: widget.type,
            original: existing,
            workspace: widget.workspace,
          ),
    );
    if (updated == null) return;
    if (widget.type == _ItemType.component) {
      final idError = ComponentRegistry.validateV4ComponentId(
        id: (updated['id'] ?? '').toString(),
        existingIds: items.map((item) => (item['id'] ?? '').toString()),
        editingId: existing?['id']?.toString(),
      );

      if (idError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(idError)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    await widget.onSave(widget.section, nextItems);
  }

  Future<void> reuseComponent(Map<String, dynamic> source) async {
    final screens = widget.workspace.items('screens');

    if (screens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedUiText('Add a screen first')),
      );
      return;
    }

    String? targetScreenId = source['screenId']?.toString();

    final selectedScreen = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (dialogContext, updateDialog) => AlertDialog(
                  title: const LocalizedUiText('Reuse component on screen'),
                  content: DropdownButtonFormField<String>(
                    initialValue:
                        screens.any((screen) => screen['id'] == targetScreenId)
                            ? targetScreenId
                            : null,
                    decoration: InputDecoration(
                      labelText: uiText(
                        context,
                        'Target screen',
                        'இலக்குத் திரை',
                      ),
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
                    onChanged:
                        (value) => updateDialog(() => targetScreenId = value),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const LocalizedUiText('Cancel'),
                    ),
                    FilledButton(
                      onPressed:
                          targetScreenId == null
                              ? null
                              : () =>
                                  Navigator.pop(dialogContext, targetScreenId),
                      child: const LocalizedUiText('Reuse'),
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

    final updatedItems = <Map<String, dynamic>>[...items, clone];

    final error = V4ComponentLayout.validate(updatedItems);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
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
    if (mounted) {
      setState(() => items = reordered);
    }
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const LocalizedUiText('Remove this item?'),
            content: const Text(
              'Linked screens/routes/components may become invalid. Validation will flag dependencies.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const LocalizedUiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const LocalizedUiText('Remove'),
              ),
            ],
          ),
    );
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: AppColors.purple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add, size: 17),
              label: const LocalizedUiText('Add'),
            ),
          ],
        ),
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
          NavigationGraphEditor(
            key: ValueKey(widget.workspace.projectId),
            workspace: widget.workspace,
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final screens = widget.workspace.items('screens');
              final diagnostics = NavigationDiagnostics.inspect(screens, items);
              final unreachable = BuilderQualityChecks.unreachableFromEntry(
                screens,
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(Icons.layers_outlined, color: AppColors.muted, size: 28),
                SizedBox(height: 8),
                Text(
                  'No items yet. Add your first item to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          )
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
            ),
        ],
      ],
    ),
  );
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({
    required this.type,
    required this.original,
    required this.workspace,
  });
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
      'visibilityEquals',
    ]) {
      fields[key] = TextEditingController(text: (item[key] ?? '').toString());
    }
    priority = (item['priority'] ?? 'Must').toString();
    componentType = (item['type'] ?? 'text').toString();
    final componentProperties = item['properties'];
    final existingVisibility =
        componentProperties is Map ? componentProperties['visibility'] : null;
    final visibility =
        existingVisibility is Map
            ? Map<String, dynamic>.from(existingVisibility)
            : <String, dynamic>{};
    visibilityMode =
        V4VisibilityRules.modes.contains(visibility['mode'])
            ? visibility['mode'].toString()
            : 'always';
    visibilityState =
        V4VisibilityRules.states.contains(visibility['state'])
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
    componentFontSize =
        storedFontSize is num
            ? storedFontSize.round().clamp(8, 96).toInt()
            : 16;
    final storedElevation =
        componentProperties is Map ? componentProperties['elevation'] : null;
    componentElevation =
        storedElevation is num
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

    componentTableStriped =
        componentProperties is Map &&
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
      text:
          (item['accessRoles'] is List)
              ? (item['accessRoles'] as List)
                  .map((role) => role.toString())
                  .join(', ')
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

  Widget input(
    String key,
    String label, {
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextFormField(
      controller: fields[key],
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator:
          required
              ? (s) =>
                  s == null || s.trim().isEmpty ? '$label is required' : null
              : null,
    ),
  );
  Widget selector(
    String label,
    String? value,
    List<Map<String, dynamic>> items,
    ValueChanged<String?> onChange,
  ) => Padding(
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChange,
      validator: (v) => v == null ? 'Select $label' : null,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final screens = widget.workspace.items('screens');
    final features = widget.workspace.items('features');
    final interactionComponents =
        widget.workspace
            .items('components')
            .where(
              (component) => V4InteractionRuleValidator.componentTriggers
                  .containsKey(component['type']),
            )
            .toList();
    final resultFields = <Widget>[];
    switch (widget.type) {
      case _ItemType.feature:
        resultFields.addAll([
          input('name', 'Feature name', required: true),
          input('description', 'Description', lines: 3),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: InputDecoration(
              labelText: uiText(context, 'Priority', 'முன்னுரிமை'),
            ),
            items:
                ['Must', 'Should', 'Could', "Won't"]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
            onChanged: (v) => setState(() => priority = v ?? 'Must'),
          ),
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
          const Text(
            'Map features to this screen',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          if (features.isEmpty)
            const Text(
              'Add features first',
              style: TextStyle(color: AppColors.muted),
            ),
          Wrap(
            spacing: 7,
            children: [
              for (final f in features)
                FilterChip(
                  label: Text((f['name'] ?? 'Unnamed').toString()),
                  selected: featureIds.contains(f['id']),
                  onSelected:
                      (selected) => setState(
                        () =>
                            selected
                                ? featureIds.add(f['id'] as String)
                                : featureIds.remove(f['id']),
                      ),
                ),
            ],
          ),
        ]);
        break;
      case _ItemType.route:
        resultFields.addAll([
          selector(
            'From screen',
            fromId,
            screens,
            (v) => setState(() => fromId = v),
          ),
          selector('To screen', toId, screens, (v) => setState(() => toId = v)),
          input('trigger', 'Trigger (e.g. tap)', required: true),
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
            }),
          ),
          DropdownButtonFormField<String>(
            initialValue: componentType,
            decoration: InputDecoration(
              labelText: uiText(context, 'Component type', 'கூறின் வகை'),
            ),
            items:
                ComponentRegistry.v4ComponentTypes
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
            onChanged: (v) => setState(() => componentType = v ?? 'text'),
          ),
          const SizedBox(height: 14),
          input('label', 'Component label', required: true),
          Builder(
            builder: (context) {
              final parents =
                  widget.workspace
                      .items('components')
                      .where(
                        (item) =>
                            V4ComponentLayout.parentTypes.contains(
                              item['type'],
                            ) &&
                            item['screenId'] == screenId &&
                            item['id'] != widget.original?['id'],
                      )
                      .toList();

              final validParent =
                  parents.any((item) => item['id'] == parentComponentId)
                      ? parentComponentId
                      : null;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('parent-$screenId-$validParent'),
                  initialValue: validParent ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: uiText(
                      context,
                      'Parent component',
                      'முதன்மைக் கூறு',
                    ),
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
                  onChanged:
                      (value) => setState(() {
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
              title: const LocalizedUiText('Required'),
              subtitle: const LocalizedUiText('Require a value for this input'),
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
                  onChanged:
                      (value) =>
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
                  onChanged:
                      (value) =>
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
                  onChanged:
                      (value) =>
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
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  'Header alignment',
                  'தலைப்பு சீரமைப்பு',
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'left', child: Text('Left')),
                DropdownMenuItem(value: 'center', child: Text('Center')),
                DropdownMenuItem(value: 'right', child: Text('Right')),
              ],
              onChanged:
                  (value) => setState(
                    () => componentHeaderAlignment = value ?? 'left',
                  ),
            ),
          if (componentType == 'list')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LocalizedUiText('Dense layout'),
              value: componentListDense,
              onChanged: (value) => setState(() => componentListDense = value),
            ),
          if (componentType == 'table')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LocalizedUiText('Striped rows'),
              value: componentTableStriped,
              onChanged:
                  (value) => setState(() => componentTableStriped = value),
            ),
          if (componentType == 'button')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LocalizedUiText('Enabled'),
              subtitle: const LocalizedUiText('Allow button interaction'),
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
            decoration: InputDecoration(
              labelText: uiText(
                context,
                'Visibility Condition',
                'காட்சிக்கான நிபந்தனை',
              ),
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
            onChanged:
                (value) => setState(() => visibilityMode = value ?? 'always'),
          ),
          const SizedBox(height: 12),
          if (visibilityMode == 'role')
            input('visibilityRole', 'Required User Role', required: true),
          if (visibilityMode == 'state')
            DropdownButtonFormField<String>(
              key: const ValueKey('visibility-state-selector'),
              initialValue: visibilityState,
              decoration: InputDecoration(
                labelText: uiText(
                  context,
                  'Required UI State',
                  'தேவையான UI நிலை',
                ),
              ),
              items: [
                for (final value in V4VisibilityRules.states)
                  DropdownMenuItem(value: value, child: Text(value)),
              ],
              onChanged:
                  (value) =>
                      setState(() => visibilityState = value ?? 'default'),
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

        final selectedType =
            selectedComponent.isEmpty
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
              initialValue:
                  interactionComponents.any(
                        (component) =>
                            component['id'] == interactionComponentId,
                      )
                      ? interactionComponentId
                      : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: uiText(context, 'Source Component', 'மூலக் கூறு'),
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
              onChanged:
                  (value) => setState(() {
                    interactionComponentId =
                        value == null || value.isEmpty ? null : value;
                    interactionTrigger = null;
                  }),
            ),
            const SizedBox(height: 14),
            if (interactionComponentId != null) ...[
              DropdownButtonFormField<String>(
                key: ValueKey('interaction-trigger-$interactionComponentId'),
                initialValue:
                    availableTriggers.contains(interactionTrigger)
                        ? interactionTrigger
                        : null,
                decoration: InputDecoration(
                  labelText: uiText(context, 'Trigger', 'தூண்டுதல்'),
                ),
                items: [
                  for (final trigger in availableTriggers)
                    DropdownMenuItem(value: trigger, child: Text(trigger)),
                ],
                onChanged:
                    (value) => setState(() => interactionTrigger = value),
                validator: (value) => value == null ? 'Select Trigger' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue:
                    V4InteractionRuleValidator.actions.contains(
                          interactionAction,
                        )
                        ? interactionAction
                        : 'navigate',
                decoration: InputDecoration(
                  labelText: uiText(context, 'Action', 'செயல்'),
                ),
                items: [
                  for (final action in [
                    'navigate',
                    'show-message',
                    'set-state',
                  ])
                    DropdownMenuItem(value: action, child: Text(action)),
                ],
                onChanged:
                    (value) =>
                        setState(() => interactionAction = value ?? 'navigate'),
              ),
              const SizedBox(height: 14),
              if (interactionAction == 'navigate')
                selector(
                  'Destination Screen',
                  interactionTargetScreenId,
                  screens,
                  (value) => setState(() => interactionTargetScreenId = value),
                ),
              if (interactionAction == 'show-message')
                input('message', 'Message text', required: true),
              if (interactionAction == 'set-state')
                DropdownButtonFormField<String>(
                  initialValue: interactionTargetState,
                  decoration: InputDecoration(
                    labelText: uiText(
                      context,
                      'Target UI State',
                      'இலக்கு UI நிலை',
                    ),
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
                      DropdownMenuItem(value: target, child: Text(target)),
                  ],
                  onChanged:
                      (value) => setState(
                        () => interactionTargetState = value ?? 'default',
                      ),
                ),
              const SizedBox(height: 14),
            ],
          ],
          DropdownButtonFormField<String>(
            initialValue: state,
            decoration: InputDecoration(
              labelText: uiText(context, 'UI State', 'UI நிலை'),
            ),
            items:
                [
                      'default',
                      'loading',
                      'empty',
                      'error',
                      'success',
                      'disabled',
                      'permission-denied',
                    ]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
            onChanged: (v) => setState(() => state = v ?? 'default'),
          ),
          const SizedBox(height: 14),
          input('description', 'Behavior / validation / recovery', lines: 3),
        ]);
        break;
    }
    return AlertDialog(
      title: Text(
        '${widget.original == null ? 'Add' : 'Edit'} ${widget.type.name}',
      ),
      content: SizedBox(
        width: 490,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: resultFields,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalizedUiText('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final result = <String, dynamic>{
              ...?widget.original,
              'id': widget.original?['id'] ?? const Uuid().v4(),
            };
            switch (widget.type) {
              case _ItemType.feature:
                result.addAll({
                  'name': fields['name']!.text.trim(),
                  'description': fields['description']!.text.trim(),
                  'priority': priority,
                  'status': 'confirmed',
                  'source': 'manual-owner',
                });
                break;
              case _ItemType.screen:
                result.addAll({
                  'name': fields['name']!.text.trim(),
                  'purpose': fields['purpose']!.text.trim(),
                  'required': true,
                  'featureIds': featureIds.toList(),
                  'accessRoles': parseScreenAccessRoles(
                    fields['accessRoles']!.text,
                  ),
                });
                break;
              case _ItemType.route:
                result.addAll({
                  'fromScreenId': fromId,
                  'toScreenId': toId,
                  'trigger': fields['trigger']!.text.trim(),
                  'name': 'Route',
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
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'placeholder': fields['placeholder']!.text.trim(),
                      'required': componentRequired,
                    },
                  if (componentType == 'text')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'fontSize': componentFontSize,
                    },
                  if (componentType == 'card')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'elevation': componentElevation,
                      'padding': componentPadding,
                    },
                  if (componentType == 'container' ||
                      componentType == 'section')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'padding': componentPadding,
                    },
                  if (componentType == 'image')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'src': fields['imageSource']!.text.trim(),
                      'alt': fields['imageAlt']!.text.trim(),
                    },
                  if (componentType == 'header')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'alignment': componentHeaderAlignment,
                    },
                  if (componentType == 'list')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'dense': componentListDense,
                    },
                  if (componentType == 'table')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'stripedRows': componentTableStriped,
                    },
                  if (componentType == 'button')
                    'properties': {
                      ...?((widget.original?['properties'] is Map)
                          ? Map<String, dynamic>.from(
                            widget.original!['properties'] as Map,
                          )
                          : null),
                      'enabled': componentEnabled,
                    },
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
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

              final visibilityError = V4VisibilityRules.validate(visibility);

              if (visibilityError != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(visibilityError)));
                return;
              }

              final currentProperties = result['properties'];
              final mergedProperties =
                  currentProperties is Map
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
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error)));
                return;
              }
            }
            Navigator.pop(context, result);
          },
          child: const LocalizedUiText('Save'),
        ),
      ],
    );
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
      text: (values['primaryColor'] ?? '#6654E8').toString(),
    );
    secondary = TextEditingController(
      text: (values['secondaryColor'] ?? '#2C8FCE').toString(),
    );
    fontFamily = TextEditingController(
      text: (values['fontFamily'] ?? 'Roboto').toString(),
    );
    baseSpacing = TextEditingController(
      text: (values['baseSpacing'] ?? 8).toString(),
    );
    borderRadius = TextEditingController(
      text: (values['borderRadius'] ?? 12).toString(),
    );
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
    int.tryParse('FF${value.replaceAll('#', '')}', radix: 16) ?? 0xFF6654E8,
  );
  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedSectionTitle(
            'Brand & theme',
            subtitle: 'Persistent design tokens used by the template renderer.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 18,
            children: [
              for (final entry in <(String, TextEditingController)>[
                ('Primary color', primary),
                ('Secondary color', secondary),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: entry.$2,
                          decoration: InputDecoration(labelText: entry.$1),
                          onChanged: (_) => setState(() {}),
                          validator:
                              (s) =>
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
                'Primary color on white: ${ratio.toStringAsFixed(2)}:1 — '
                '${passes ? 'WCAG AA normal-text contrast passed' : 'Low contrast: use a darker primary color'}',
                style: TextStyle(
                  color:
                      passes
                          ? const Color(0xFF16734C)
                          : const Color(0xFFB42318),
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
                'Secondary color on white: ${ratio.toStringAsFixed(2)}:1 — '
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
            validator:
                (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a font family' : null,
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
            decoration: InputDecoration(
              labelText: uiText(context, 'Color mode', 'நிற முறை'),
            ),
            items:
                ['light', 'dark', 'system']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
            onChanged: (v) => setState(() => mode = v ?? 'light'),
          ),
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
            label: const LocalizedUiText('Save Theme'),
          ),
        ],
      ),
    ),
  );
}

final projectValidationProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(workspaceRepositoryProvider).validate(id),
    );

/// Testable Step 07 Blueprint studio.
class V4BlueprintStudio extends StatelessWidget {
  const V4BlueprintStudio({super.key, required this.workspace});

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

  late int _editingVersion;
  int? _savedVersion;
  Map<String, dynamic>? _savedSnapshot;
  bool _versionConflict = false;
  final BlueprintRecoveryStore _recoveryStore = BlueprintRecoveryStore();
  late final WorkspaceRepository _repository;
  late final int _sessionGeneration;
  late final String? _recoveryKey;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(workspaceRepositoryProvider);
    _editingVersion = widget.workspace.version;
    _sessionGeneration = authSession.generation;
    final actorId = projectMemberActorId(authSession.token);
    _recoveryKey =
        isLocalDemo
            ? 'demo:${widget.workspace.projectId}'
            : actorId == null
            ? null
            : '$actorId:$_sessionGeneration:${widget.workspace.projectId}';
    final key = _recoveryKey;
    if (key != null) {
      final restored = _recoveryStore.restore(key, _editingVersion);
      if (restored != null) {
        draftBlueprint = restored;
        blueprintHistory = V4BlueprintHistory(restored);
      }
    }
  }

  void _persistRecovery() {
    final key = _recoveryKey;
    final draft = draftBlueprint;
    if (key != null &&
        draft != null &&
        authSession.generation == _sessionGeneration &&
        !_versionConflict) {
      _recoveryStore.save(key, _editingVersion, draft);
    }
  }

  void _clearRecovery() {
    final key = _recoveryKey;
    if (key != null) _recoveryStore.clear(key);
  }

  @override
  void didUpdateWidget(covariant _BlueprintEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final version = widget.workspace.version;

    if (version == oldWidget.workspace.version) return;

    if (version == _savedVersion) {
      _editingVersion = version;
      _savedVersion = null;
      _savedSnapshot = null;
      return;
    }

    if (draftBlueprint != null || savingDraft) {
      _autosaveTimer?.cancel();
      _versionConflict = true;
      error =
          'The workspace changed. Discard local changes and reload before editing.';
      return;
    }

    _editingVersion = version;
    _savedVersion = null;
    _savedSnapshot = null;
    _versionConflict = false;
    blueprintHistory = null;
    localPreview = null;
    selectedBlueprintComponentId = null;
    inspectorRevision++;
  }

  Timer? _autosaveTimer;

  void scheduleAutosave() {
    _persistRecovery();
    _autosaveTimer?.cancel();
    if (!autosaveEnabled || draftBlueprint == null || _versionConflict) return;

    _autosaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          !savingDraft &&
          !generating &&
          authSession.generation == _sessionGeneration) {
        saveBlueprintDraft();
      }
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    final pendingBlueprint = draftBlueprint;
    if (autosaveEnabled &&
        pendingBlueprint != null &&
        !savingDraft &&
        !generating &&
        !_versionConflict &&
        authSession.generation == _sessionGeneration) {
      unawaited(
        _repository
            .save(
              widget.workspace.projectId,
              'visualEditorDraft',
              _editingVersion,
              pendingBlueprint,
            )
            .then<void>((_) {})
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  String? error;
  String? selectedBlueprintComponentId;
  Map<String, dynamic>? draftBlueprint;
  Map<String, dynamic>? localPreview;
  V4BlueprintHistory? blueprintHistory;
  int inspectorRevision = 0;

  void undoBlueprint() {
    if (savingDraft || generating || _versionConflict) return;
    final restored = blueprintHistory?.undo();
    if (restored == null) return;

    setState(() {
      draftBlueprint = restored;
      inspectorRevision++;
    });
    scheduleAutosave();
  }

  void redoBlueprint() {
    if (savingDraft || generating || _versionConflict) return;
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
      final id =
          (component['componentInstanceId'] ?? component['id'] ?? '')
              .toString();
      if (id == selectedId) return component;
    }
    return null;
  }

  // Edits are local preview-only. Never represent them as saved or approved.
  void updateDraftComponent(
    Map<String, dynamic> blueprint,
    Map<String, dynamic> updated,
  ) {
    if (savingDraft || generating || _versionConflict) return;
    final id =
        (updated['componentInstanceId'] ?? updated['id'] ?? '').toString();
    if (id.isEmpty || id != selectedBlueprintComponentId) return;

    final rawComponents = blueprint['componentInstances'];
    if (rawComponents is! List) return;

    var found = false;
    final components =
        rawComponents.map((raw) {
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
    final history =
        blueprintHistory ??= V4BlueprintHistory(
          widget.workspace.fields('visualEditorDraft'),
        );

    if (!history.record(nextBlueprint)) return;

    setState(() {
      draftBlueprint = history.current;
    });
    scheduleAutosave();
  }

  Future<void> discardVisualChanges() async {
    if (savingDraft || generating || draftBlueprint == null) return;

    _autosaveTimer?.cancel();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: const LocalizedUiText('Discard unsaved visual changes?'),
            content: const LocalizedUiText(
              'Your last saved visual draft will remain unchanged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const LocalizedUiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const LocalizedUiText('Discard changes'),
              ),
            ],
          ),
    );

    if (!mounted) return;

    if (confirmed != true) {
      scheduleAutosave();
      return;
    }

    _clearRecovery();
    setState(() {
      draftBlueprint = null;
      localPreview = null;
      blueprintHistory = null;
      selectedBlueprintComponentId = null;
      inspectorRevision++;
      _editingVersion = widget.workspace.version;
      _savedSnapshot = null;
      _savedVersion = null;
      _versionConflict = false;
      error = null;
    });

    ref.invalidate(workspaceProvider(widget.workspace.projectId));
  }

  Future<void> saveBlueprintDraft() async {
    final nextBlueprint = draftBlueprint;

    if (nextBlueprint == null ||
        savingDraft ||
        generating ||
        _versionConflict ||
        authSession.generation != _sessionGeneration) {
      return;
    }

    _autosaveTimer?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      savingDraft = true;
      error = null;
    });

    try {
      final version = await ref
          .read(workspaceRepositoryProvider)
          .save(
            widget.workspace.projectId,
            'visualEditorDraft',
            _editingVersion,
            nextBlueprint,
          );

      if (!mounted) return;

      _clearRecovery();
      setState(() {
        _editingVersion = version;
        _savedVersion = version;
        _savedSnapshot = nextBlueprint;
        draftBlueprint = null;
        localPreview = null;
      });

      ref.invalidate(workspaceProvider(widget.workspace.projectId));
      ref.invalidate(projectValidationProvider(widget.workspace.projectId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Blueprint draft saved - v$version '
            '(visual editor; not approved)',
          ),
        ),
      );
    } catch (failure) {
      if (mounted) {
        setState(() {
          error = 'Blueprint draft was not saved: $failure';

          if (failure is StateError ||
              (failure is ApiException && failure.statusCode == 409)) {
            _versionConflict = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => savingDraft = false);
      }
    }
  }

  Future<void> generatePreview() async {
    if (savingDraft || generating || _versionConflict) {
      return;
    }

    final savedVisualDraft = widget.workspace.fields('visualEditorDraft');
    final canonicalBlueprint = widget.workspace.fields('blueprint');
    final currentBlueprint =
        draftBlueprint ??
        (savedVisualDraft['screens'] is List
            ? savedVisualDraft
            : canonicalBlueprint);
    final hasExistingDesign =
        currentBlueprint['screens'] is List &&
        (currentBlueprint['screens'] as List).isNotEmpty;

    if (hasExistingDesign) {
      final replace = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Replace the current Blueprint draft?'),
              content: const Text(
                'Generating again replaces the working preview. '
                'You can undo the replacement until it is saved.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep Current'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Replace Draft'),
                ),
              ],
            ),
      );
      if (replace != true || !mounted) return;
    }

    try {
      // Derived from server-loaded Workspace content, not hardcoded DB records.
      final preview = buildLocalPreviewBlueprint(widget.workspace);
      final history =
          hasExistingDesign
              ? (blueprintHistory ?? V4BlueprintHistory(currentBlueprint))
              : V4BlueprintHistory(preview);
      if (hasExistingDesign) history.record(preview);
      setState(() {
        localPreview = preview;
        draftBlueprint = history.current;
        blueprintHistory = history;
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

  /// Saves Backend Blueprint v1 without approving it.
  Future<void> saveOfficialBlueprintV1() async {
    if (generating || savingDraft || draftBlueprint != null) return;

    _autosaveTimer?.cancel();

    setState(() {
      generating = true;
      error = null;
    });

    try {
      final blueprint = buildBackendBlueprintV1(widget.workspace);

      final savedVersion = await ref
          .read(workspaceRepositoryProvider)
          .saveBackendBlueprint(
            widget.workspace.projectId,
            widget.workspace.version,
            blueprint,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Official Blueprint v1 saved - v$savedVersion. '
            'Validation and approval are still required.',
          ),
        ),
      );

      ref.invalidate(projectValidationProvider(widget.workspace.projectId));
      ref.invalidate(workspaceProvider(widget.workspace.projectId));
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Official Blueprint v1 was not saved: $e';
        });
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> regenerateBlueprint() async {
    if (generating ||
        savingDraft ||
        draftBlueprint != null ||
        _versionConflict) {
      return;
    }

    final projectId = widget.workspace.projectId;
    final workspaceRepository = ref.read(workspaceRepositoryProvider);
    final repository = ref.read(aiIntelligenceRepositoryProvider);

    setState(() {
      generating = true;
      error = null;
    });

    try {
      final current = Map<String, dynamic>.from(
        await workspaceRepository.api.get(
              '/api/projects/$projectId/drafts/current',
            )
            as Map,
      );

      if (!mounted) return;

      if (current['version'] != widget.workspace.version) {
        throw StateError('Workspace changed. Reload and retry.');
      }

      final token = current['concurrencyToken'];

      final saved = Map<String, dynamic>.from(
        await workspaceRepository.api.get(
              '/api/projects/$projectId/blueprints/current',
            )
            as Map,
      );

      if (!mounted) return;

      if (saved['version'] != current['version']) {
        throw StateError('Blueprint version changed. Reload and retry.');
      }

      final blueprint = saved['blueprint'];

      if (blueprint is! Map || blueprint.isEmpty) {
        throw StateError('Generate a saved Blueprint first.');
      }

      final revision = blueprint['revision'];

      if (token is! String ||
          token.isEmpty ||
          revision is! int ||
          revision < 1) {
        throw StateError('Invalid saved Blueprint revision.');
      }

      List<Map<String, dynamic>> rows(String section) {
        final rows = blueprint[section];

        if (rows is! List) {
          throw StateError('Missing Blueprint section: $section');
        }

        return rows.map((row) {
          if (row is! Map ||
              row['id'] is! String ||
              (row['id'] as String).isEmpty) {
            throw StateError('Invalid $section identifier');
          }

          return Map<String, dynamic>.from(row);
        }).toList();
      }

      final features = rows('features');
      final screens = rows('screens');
      final components = rows('components');
      final editableFeatureIds = <String>{};
      final editableScreenIds = <String>{};
      final editableComponentIds = <String>{};

      final accepted = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => StatefulBuilder(
              builder:
                  (context, update) => AlertDialog(
                    title: const LocalizedUiText('Safe Regeneration'),
                    content: SizedBox(
                      width: 520,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Blueprint revision: $revision'),
                            const SizedBox(height: 12),
                            const Text(
                              'Select the existing items the server may '
                              'replace. Unselected and user-edited items '
                              'remain protected.',
                            ),
                            const SizedBox(height: 12),
                            for (final entry in <
                              (String, List<Map<String, dynamic>>, Set<String>)
                            >[
                              ('Features', features, editableFeatureIds),
                              ('Screens', screens, editableScreenIds),
                              ('Components', components, editableComponentIds),
                            ]) ...[
                              Text(
                                entry.$1,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              for (final row in entry.$2)
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  value: entry.$3.contains(row['id']),
                                  title: Text(
                                    (row['name'] ?? row['label'] ?? row['id'])
                                        .toString(),
                                  ),
                                  subtitle: Text(row['id'].toString()),
                                  onChanged:
                                      (selected) => update(() {
                                        final id = row['id'] as String;
                                        if (selected == true) {
                                          entry.$3.add(id);
                                        } else {
                                          entry.$3.remove(id);
                                        }
                                      }),
                                ),
                              const SizedBox(height: 8),
                            ],
                            const Text(
                              'The server validates the regenerated draft. '
                              'This action does not approve the design.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const LocalizedUiText('Cancel'),
                      ),
                      FilledButton(
                        onPressed:
                            editableFeatureIds.isEmpty &&
                                    editableScreenIds.isEmpty &&
                                    editableComponentIds.isEmpty
                                ? null
                                : () => Navigator.pop(dialogContext, true),
                        child: const LocalizedUiText('Regenerate'),
                      ),
                    ],
                  ),
            ),
      );

      if (!mounted || accepted != true) return;

      final response = await repository.regenerateBlueprint(
        projectId: projectId,
        expectedConcurrencyToken: token,
        expectedRevision: revision,
        editableFeatureIds: editableFeatureIds.toList(growable: false),
        editableScreenIds: editableScreenIds.toList(growable: false),
        editableComponentIds: editableComponentIds.toList(growable: false),
      );

      if (!mounted) return;

      if (response['version'] is! int || response['draft'] is! Map) {
        throw const FormatException('Invalid regeneration response.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Regenerated Blueprint saved - '
            'draft v${response['version']}',
          ),
        ),
      );

      ref.invalidate(projectValidationProvider(projectId));
      ref.invalidate(workspaceProvider(projectId));
    } catch (failure) {
      if (!mounted) return;

      setState(() {
        if (failure is ApiException && failure.statusCode == 503) {
          error = 'AI provider is unavailable or awaiting approval.';
        } else if (failure is ApiException && failure.statusCode == 409) {
          error = 'Blueprint changed. Reload before regenerating.';
        } else {
          error = failure.toString();
        }
      });
    } finally {
      if (mounted) {
        setState(() => generating = false);
      }
    }
  }

  Future<void> compileBlueprint() async {
    if (generating || savingDraft || draftBlueprint != null) return;

    setState(() {
      generating = true;
      error = null;
    });

    try {
      final workspace = widget.workspace;
      final projectId = workspace.projectId;
      final repository = ref.read(aiIntelligenceRepositoryProvider);
      final workspaceRepository = ref.read(workspaceRepositoryProvider);

      final latest = await workspaceRepository.load(projectId);

      if (!mounted) return;

      if (latest.version != workspace.version) {
        throw StateError('Workspace changed. Reload before generating.');
      }

      final confirmed = <String, Map<String, dynamic>>{};

      for (final candidate in latest.items('aiCandidates')) {
        final id = candidate['id']?.toString() ?? '';

        if (id.isEmpty) continue;

        Map<String, dynamic> review;

        try {
          review = await repository.getReview(projectId, id);
        } on ApiException catch (failure) {
          if (failure.statusCode == 404) continue;
          rethrow;
        }

        final status = review['status']?.toString().toLowerCase();

        if (status == 'confirmed' || status == '1') {
          confirmed[id] = review;
        }
      }

      if (!mounted) return;

      if (confirmed.isEmpty) {
        throw StateError(
          'Confirm requirements through the server review workflow first.',
        );
      }

      final confirmedGeneration = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const LocalizedUiText('Generate Blueprint'),
              content: Text(
                'Generate a server-managed draft from '
                '${confirmed.length} confirmed requirements? '
                'The backend determines the initial feature, screen, and '
                'navigation graph. The result is not approved automatically.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const LocalizedUiText('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const LocalizedUiText('Generate & save'),
                ),
              ],
            ),
      );

      if (!mounted || confirmedGeneration != true) return;

      final current = Map<String, dynamic>.from(
        await workspaceRepository.api.get(
              '/api/projects/$projectId/drafts/current',
            )
            as Map,
      );

      if (!mounted) return;

      final currentVersion = (current['version'] as num?)?.toInt();

      if (currentVersion != latest.version) {
        throw StateError('Draft changed during mapping. Reload and retry.');
      }

      final token = current['concurrencyToken'];

      if (token is! String || token.isEmpty) {
        throw StateError('Missing draft concurrency token.');
      }

      final response = await repository.generateBlueprint(
        projectId: projectId,
        expectedConcurrencyToken: token,
        confirmedRequirementIds: confirmed.keys.toList(growable: false),
      );

      if (!mounted) return;

      if (response['version'] is! int || response['draft'] is! Map) {
        throw const FormatException('Invalid Blueprint generation response.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blueprint saved - draft v${response['version']}'),
        ),
      );

      ref.invalidate(projectValidationProvider(projectId));
      ref.invalidate(workspaceProvider(projectId));
    } catch (failure) {
      if (mounted) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted) {
        setState(() => generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedVisualDraft = widget.workspace.fields('visualEditorDraft');
    final canonicalBlueprint = widget.workspace.fields('blueprint');
    final savedBlueprint =
        _savedSnapshot ??
        (savedVisualDraft['screens'] is List
            ? savedVisualDraft
            : canonicalBlueprint);
    final visibleBlueprint = draftBlueprint ?? savedBlueprint;
    final hasCompiledBlueprint = visibleBlueprint['screens'] is List;
    final interactionRules = widget.workspace.items('interactions');

    if (hasCompiledBlueprint) {
      blueprintHistory ??= V4BlueprintHistory(visibleBlueprint);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LocalizedSectionTitle(
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
                    label: const LocalizedUiText('Autosave (2s)'),
                    selected: autosaveEnabled,
                    onSelected:
                        savingDraft || generating
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
                    onPressed:
                        generating ||
                                savingDraft ||
                                draftBlueprint != null ||
                                _versionConflict
                            ? null
                            : generatePreview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const LocalizedUiText('Generate Local Preview'),
                  ),
                  if (draftBlueprint != null)
                    OutlinedButton.icon(
                      key: const ValueKey('step07-discard-button'),
                      onPressed:
                          savingDraft || generating
                              ? null
                              : discardVisualChanges,
                      icon: const Icon(Icons.restore),
                      label: const LocalizedUiText('Discard Changes'),
                    ),
                  if (draftBlueprint != null)
                    FilledButton.icon(
                      key: const ValueKey('step07-save-draft-button'),
                      onPressed:
                          savingDraft || generating ? null : saveBlueprintDraft,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        savingDraft ? 'Saving Draft...' : 'Save Visual Draft',
                      ),
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('step07-save-official-blueprint-v1'),
                    onPressed:
                        generating || savingDraft || draftBlueprint != null
                            ? null
                            : saveOfficialBlueprintV1,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Save Official Blueprint v1'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        generating || savingDraft || draftBlueprint != null
                            ? null
                            : compileBlueprint,
                    icon: const Icon(Icons.auto_awesome),
                    label: const LocalizedUiText('Generate & Save Blueprint'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        generating || savingDraft || draftBlueprint != null
                            ? null
                            : regenerateBlueprint,
                    icon: const Icon(Icons.auto_awesome),
                    label: const LocalizedUiText('Safe AI Regeneration'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Generate and edit a visual draft separately from the backend Blueprint. '
                'Visual draft changes do not modify or approve the canonical Blueprint.',
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
          const LocalizedSectionTitle('Local simulation - not validated'),
          const SizedBox(height: 8),
          SafePreview(
            key: ObjectKey(localPreview),
            blueprint: localPreview!,
            interactionRules: interactionRules,
          ),
        ],
        const SizedBox(height: 16),
        const LocalizedSectionTitle('Visual Design Workspace'),
        const SizedBox(height: 8),
        if (hasCompiledBlueprint) ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('step07-undo-button'),
                onPressed:
                    !savingDraft &&
                            !generating &&
                            !_versionConflict &&
                            blueprintHistory?.canUndo == true
                        ? undoBlueprint
                        : null,
                icon: const Icon(Icons.undo),
                label: const LocalizedUiText('Undo'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('step07-redo-button'),
                onPressed:
                    !savingDraft &&
                            !generating &&
                            !_versionConflict &&
                            blueprintHistory?.canRedo == true
                        ? redoBlueprint
                        : null,
                icon: const Icon(Icons.redo),
                label: const LocalizedUiText('Redo'),
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
              child: IgnorePointer(
                ignoring: savingDraft || generating || _versionConflict,
                child: ExcludeFocus(
                  excluding: savingDraft || generating || _versionConflict,
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
  const _ValidationEditor({required this.workspace, required this.role});

  final Workspace workspace;
  final ProjectMemberRole role;

  @override
  ConsumerState<_ValidationEditor> createState() => _ValidationEditorState();
}

class _ValidationEditorState extends ConsumerState<_ValidationEditor> {
  bool busy = false;
  String? error;
  String? message;
  String? validationToken;
  String? approvedRevisionId;

  Map<String, dynamic>? result;

  List<Map<String, dynamic>> revisions = [];
  List<Map<String, dynamic>> exports = [];

  String get projectId => widget.workspace.projectId;

  @override
  void initState() {
    super.initState();
    approvedRevisionId = approvedRevisionSession.read(
      projectId,
      widget.workspace.version,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadHistory();
    });
  }

  @override
  void didUpdateWidget(covariant _ValidationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.workspace.version != widget.workspace.version ||
        oldWidget.workspace.projectId != projectId) {
      result = null;
      validationToken = null;
    }

    if (oldWidget.workspace.projectId != projectId) {
      revisions = [];
      exports = [];
    }
  }

  Future<Map<String, dynamic>> currentDraft() async {
    final repository = ref.read(workspaceRepositoryProvider);

    return Map<String, dynamic>.from(
      await repository.api.get('/api/projects/$projectId/drafts/current')
          as Map,
    );
  }

  String describeError(Object failure) {
    if (failure is ApiException) {
      switch (failure.statusCode) {
        case 401:
          return 'Session expired. Sign in again.';
        case 403:
          return 'You do not have permission for this operation.';
        case 409:
          return 'The draft has changed or is already approved. Reload and retry.';
        case 404:
          return 'The requested revision or draft was not found.';
      }
    }

    return failure.toString();
  }

  Future<void> execute(Future<void> Function() operation) async {
    if (busy) return;

    setState(() {
      busy = true;
      error = null;
      message = null;
    });

    try {
      await operation();
    } catch (failure) {
      if (mounted) {
        setState(() => error = describeError(failure));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> refreshHistory() async {
    final repository = ref.read(approvalExportRepositoryProvider);

    final approved = await repository.getRevisions(projectId);

    if (!mounted) return;

    setState(() => revisions = approved);

    if (widget.role != ProjectMemberRole.owner) {
      if (mounted) setState(() => exports = []);
      return;
    }

    try {
      final records = await repository.getExports(projectId);

      if (mounted) {
        setState(() => exports = records);
      }
    } on ApiException catch (failure) {
      if (failure.statusCode != 403) rethrow;

      if (mounted) {
        setState(() {
          exports = [];
          message = 'Export records are available to project owners.';
        });
      }
    }
  }

  Future<void> loadHistory() => execute(refreshHistory);

  Future<void> runValidation() => execute(() async {
    if (widget.role == ProjectMemberRole.viewer) {
      throw StateError('Project editor access is required for validation.');
    }
    if (widget.workspace.isApproved) {
      throw StateError('This draft is already approved.');
    }
    setState(() {
      result = null;
      validationToken = null;
    });

    final current = await currentDraft();

    if (!mounted) return;

    if (current['version'] != widget.workspace.version) {
      throw StateError('Workspace changed. Reload before validation.');
    }

    final token = current['concurrencyToken'];

    if (token is! String || token.isEmpty) {
      throw StateError('Save the current draft before validation.');
    }

    final repository = ref.read(workspaceRepositoryProvider);

    final response = Map<String, dynamic>.from(
      await repository.api.post(
            '/api/projects/$projectId/blueprints/validate',
            {'expectedConcurrencyToken': token},
          )
          as Map,
    );

    if (response['findings'] is! List) {
      throw const FormatException('Invalid validation response');
    }

    final backendPassed = response['passed'];
    final blockers = response['blockers'];
    if (backendPassed is! bool && blockers is! int) {
      response['readinessKnown'] = false;
    } else {
      response['readinessKnown'] = true;
      response['passed'] =
          backendPassed is bool ? backendPassed : blockers == 0;
    }

    if (!mounted) return;

    setState(() {
      result = response;
      validationToken = token;
      message =
          response['passed'] == true
              ? 'Backend validation passed.'
              : 'Validation failed. Resolve the findings before approval.';
    });
  });

  Future<void> approveDraft() => execute(() async {
    if (widget.role != ProjectMemberRole.owner) {
      throw StateError('Only the project owner can approve a revision.');
    }
    if (widget.workspace.isApproved) {
      throw StateError('This draft is already approved.');
    }
    final validation = result;
    final token = validationToken;

    if (validation?['passed'] != true ||
        validation?['id'] is! String ||
        token == null) {
      throw StateError('Successful validation is required.');
    }

    final current = await currentDraft();

    if (!mounted) return;

    if (current['approvedRevisionId'] != null) {
      throw StateError('This draft is already approved.');
    }

    if (current['concurrencyToken'] != token ||
        current['version'] != widget.workspace.version) {
      setState(() {
        result = null;
        validationToken = null;
      });

      throw StateError('Draft changed. Run validation again.');
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const LocalizedUiText('Approve Blueprint revision?'),
            content: const Text(
              'Approval creates an immutable revision of the current '
              'validated Blueprint. Confirm only after reviewing the design.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const LocalizedUiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const LocalizedUiText('Confirm Approval'),
              ),
            ],
          ),
    );

    if (!mounted || confirmed != true) return;

    final repository = ref.read(workspaceRepositoryProvider);

    final receipt = await repository.approveValidatedDraft(
      projectId,
      widget.workspace.version,
      validation!['id'] as String,
    );

    if (receipt['revisionId'] is! String) {
      throw const FormatException('Invalid approval receipt');
    }

    if (!mounted) return;

    setState(() {
      validationToken = null;
      approvedRevisionId = receipt['revisionId'] as String;
      message = 'Approved revision created successfully.';
    });

    approvedRevisionSession.remember(
      projectId,
      widget.workspace.version,
      approvedRevisionId!,
    );

    ref.invalidate(workspaceProvider(projectId));
    ref.invalidate(projectValidationProvider(projectId));

    try {
      await refreshHistory();
    } catch (_) {
      // The approval receipt is authoritative even if optional history
      // endpoints are unavailable on an older backend deployment.
    }
  });

  Future<void> exportOfficialRevision() => execute(() async {
    if (widget.role != ProjectMemberRole.owner) {
      throw StateError('Only the project owner can export a revision.');
    }
    final revisionId = approvedRevisionId;
    if (revisionId == null) {
      throw StateError('Approve a validated revision before exporting.');
    }

    final repository = ref.read(workspaceRepositoryProvider);
    final receipt = await repository.createOfficialExport(
      projectId,
      revisionId,
    );
    final exportId = receipt['exportId'];
    if (exportId is! String || exportId.isEmpty) {
      throw const FormatException('Backend returned no official export ID.');
    }

    final bytes = await repository.downloadOfficialExport(projectId, exportId);
    if (!isStructurallyValidZip(bytes)) {
      throw const FormatException('Official export has no valid ZIP header.');
    }
    if (!mounted) return;

    ref
        .read(downloadPortProvider)
        .saveZip('reqviora-$projectId-$revisionId.zip', bytes);
    setState(() => message = 'Official archive sent to browser download.');
  });

  Future<void> inspectRevision(String revisionId) => execute(() async {
    final repository = ref.read(approvalExportRepositoryProvider);

    final revision = await repository.getRevision(projectId, revisionId);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const LocalizedUiText('Approved revision details'),
            content: SingleChildScrollView(
              child: SelectableText(
                'Revision: ${revision['revisionId']}\n'
                'Draft version: ${revision['draftVersion']}\n'
                'Approved at: ${revision['approvedAt']}\n'
                'Approved by: ${revision['approvedBy']}\n'
                'Validation: ${revision['validationRunId']}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const LocalizedUiText('Close'),
              ),
            ],
          ),
    );
  });

  Future<void> createExport(String revisionId) => execute(() async {
    if (widget.role != ProjectMemberRole.owner) {
      throw StateError('Only the project owner can create an export.');
    }
    final repository = ref.read(approvalExportRepositoryProvider);

    final receipt = await repository.createExport(projectId, revisionId);

    if (receipt['exportId'] is! String ||
        receipt['approvedRevisionId'] != revisionId) {
      throw const FormatException('Invalid export receipt');
    }

    if (!mounted) return;

    setState(() {
      message = 'Official export is ready for download.';
    });

    await refreshHistory();
  });

  Future<void> downloadExport(String exportId) => execute(() async {
    if (widget.role != ProjectMemberRole.owner) {
      throw StateError('Only the project owner can download an export.');
    }
    final repository = ref.read(approvalExportRepositoryProvider);

    final metadata = await repository.getExport(projectId, exportId);

    if (metadata['exportId'] != exportId) {
      throw const FormatException('Export identity mismatch');
    }

    final bytes = await repository.downloadExport(projectId, exportId);

    if (metadata['archiveBytes'] is! int ||
        metadata['archiveBytes'] != bytes.length) {
      throw const FormatException('Archive size mismatch');
    }

    if (!isStructurallyValidZip(bytes)) {
      throw const FormatException('Invalid ZIP archive structure');
    }

    if (!mounted) return;

    ref.read(downloadPortProvider).saveZip('reqviora-$exportId.zip', bytes);

    setState(() {
      message = 'Official archive sent to browser download.';
    });
  });

  @override
  Widget build(BuildContext context) {
    final current = result;
    final passed = current?['passed'] == true;
    final readinessKnown = current?['readinessKnown'] != false;
    final approved = widget.workspace.isApproved || approvedRevisionId != null;
    final policy = ProjectEditPolicy(role: widget.role, approved: approved);

    final findings =
        (current?['findings'] as List? ?? []).whereType<Map>().toList();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedSectionTitle(
            'Review, Approval & Export',
            subtitle:
                'Validate the current design and manage approved revisions.',
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('step08-validation-button'),
                onPressed:
                    !policy.canValidate || busy || approved
                        ? null
                        : runValidation,
                icon: const Icon(Icons.fact_check_outlined),
                label: const LocalizedUiText('Run Backend Validation'),
              ),
              FilledButton.icon(
                key: const ValueKey('step08-approve-button'),
                onPressed:
                    !policy.canApprove ||
                            busy ||
                            !passed ||
                            validationToken == null
                        ? null
                        : approveDraft,
                icon: const Icon(Icons.verified_outlined),
                label: const LocalizedUiText('Approve Design'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : loadHistory,
                icon: const Icon(Icons.refresh),
                label: const LocalizedUiText('Refresh History'),
              ),
            ],
          ),

          if (busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(value: 0.5),
          ],

          const SizedBox(height: 12),

          if (current == null)
            const LocalizedUiText(
              'Run validation before approving this design.',
            )
          else ...[
            Text(
              passed
                  ? 'Backend validation passed'
                  : 'Backend validation failed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: passed ? Colors.green : Colors.red,
              ),
            ),
            Text('Validation ID: ${current['id']}'),
            Text('Validated at: ${current['validatedAt']}'),
            if (current['blockers'] is int)
              Text('${current['blockers']} blockers'),
            if (current['advisories'] is int)
              Text('${current['advisories']} advisories'),
            Text(
              !readinessKnown
                  ? 'Validation result is incomplete. Approval readiness is unknown.'
                  : passed
                  ? 'Validation passed. Approval is still required.'
                  : 'Validation blocked: resolve findings before approval.',
              key: ValueKey(
                !readinessKnown
                    ? 'step08-validation-incomplete'
                    : passed
                    ? 'step08-validation-ready'
                    : 'step08-validation-blocked',
              ),
            ),
            if (findings.isEmpty)
              const Text('No validation findings returned.'),

            for (final finding in findings)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(
                  (finding['ruleId'] ?? finding['code'] ?? 'Finding')
                      .toString(),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((finding['message'] ?? '').toString()),
                    if ((finding['path'] ?? '').toString().isNotEmpty)
                      Text(finding['path'].toString()),
                  ],
                ),
              ),
          ],

          if (approvedRevisionId != null) ...[
            const SizedBox(height: 12),
            Text(
              'Approved revision: $approvedRevisionId',
              key: const ValueKey('step08-approved-revision'),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            approvedRevisionId == null
                ? 'Official ZIP export requires a successfully approved revision.'
                : 'Download the official ZIP for the approved revision.',
            key: const ValueKey('step08-export-unavailable'),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('step08-export-disabled'),
            onPressed:
                !policy.canExport || busy || approvedRevisionId == null
                    ? null
                    : exportOfficialRevision,
            icon: const Icon(Icons.download_outlined),
            label: const LocalizedUiText('Download Official ZIP'),
          ),

          const Divider(height: 36),

          const LocalizedSectionTitle(
            'Approved Revision History',
            subtitle: 'Immutable server-approved design snapshots.',
          ),

          if (revisions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LocalizedUiText('No approved revisions loaded.'),
            ),

          for (final revision in revisions)
            if (revision['revisionId'] is String)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approved draft v${revision['draftVersion']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('${revision['approvedAt']}'),
                      SelectableText(revision['revisionId'].toString()),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed:
                                busy
                                    ? null
                                    : () => inspectRevision(
                                      revision['revisionId'] as String,
                                    ),
                            child: const LocalizedUiText('Revision details'),
                          ),
                          if (policy.canExport)
                            FilledButton.icon(
                              onPressed:
                                  busy
                                      ? null
                                      : () => createExport(
                                        revision['revisionId'] as String,
                                      ),
                              icon: const Icon(Icons.archive_outlined),
                              label: const LocalizedUiText(
                                'Create Official Export',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

          const Divider(height: 36),

          const LocalizedSectionTitle(
            'Official Second Brain Exports',
            subtitle: 'Download archives created from approved revisions.',
          ),
          const SizedBox(height: 12),
          SecondBrainViewerButton(projectId: projectId),

          if (policy.canExport && exports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LocalizedUiText('No official export records loaded.'),
            ),

          for (final item in policy.canExport ? exports : const [])
            if (item['exportId'] is String)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Export: ${item['exportId']}'),
                      Text('Revision: ${item['approvedRevisionId']}'),
                      Text('Generator: ${item['generatorVersion']}'),
                      Text('Size: ${item['archiveBytes']} bytes'),
                      Text('Created: ${item['createdAt']}'),
                      const SizedBox(height: 8),
                      SelectableText('SHA-256: ${item['archiveSha256']}'),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed:
                            busy
                                ? null
                                : () =>
                                    downloadExport(item['exportId'] as String),
                        icon: const Icon(Icons.download_outlined),
                        label: const LocalizedUiText('Download Official ZIP'),
                      ),
                    ],
                  ),
                ),
              ),

          if (message != null) ...[const SizedBox(height: 12), Text(message!)],

          if (error != null) ...[
            const SizedBox(height: 12),
            InlineError(error!),
          ],
        ],
      ),
    );
  }
}
