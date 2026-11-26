import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../../auth/application/auth_providers.dart';
import '../data/revision_history_repository.dart';
import 'simulated_preview.dart';

class RevisionHistoryPanel extends ConsumerStatefulWidget {
  const RevisionHistoryPanel({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<RevisionHistoryPanel> createState() =>
      _RevisionHistoryPanelState();
}

class _RevisionHistoryPanelState extends ConsumerState<RevisionHistoryPanel> {
  List<HistoricalDesign> _records = [];

  HistoricalDesign? _selected;

  bool _approved = true;
  bool _busy = false;
  bool _loaded = false;

  String? _error;

  int _generation = authSession.generation;
  int _operation = 0;

  RevisionHistoryRepository get _repository =>
      RevisionHistoryRepository(ref.read(authRepositoryProvider).api);

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _clear() {
    _operation++;
    _records = [];
    _selected = null;
    _loaded = false;
    _busy = false;
    _error = null;
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;

    setState(_clear);
  }

  @override
  void didUpdateWidget(covariant RevisionHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      _clear();
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    super.dispose();
  }

  bool _active(int operation) =>
      mounted &&
      authSession.authenticated &&
      _generation == authSession.generation &&
      _operation == operation;

  String _message(Object error) {
    if (error is ApiException && error.statusCode == 403) {
      return uiText(
        context,
        'You do not have permission to view this history.',
        'இந்த வரலாற்றைப் பார்க்க உங்களுக்கு அனுமதி இல்லை.',
      );
    }

    return uiText(
      context,
      'History could not be loaded. Please retry.',
      'வரலாற்றைப் பெற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
    );
  }

  Future<void> _load(bool approved) async {
    if (_busy || isLocalDemo || !authSession.authenticated) {
      return;
    }

    final operation = ++_operation;
    final projectId = widget.projectId;

    setState(() {
      _approved = approved;
      _busy = true;
      _loaded = false;
      _records = [];
      _selected = null;
      _error = null;
    });

    try {
      final result =
          approved
              ? await _repository.approvedHistory(projectId)
              : await _repository.draftHistory(projectId);

      if (!_active(operation)) return;

      setState(() {
        _records = result;
        _loaded = true;
      });
    } catch (error) {
      if (!_active(operation)) return;

      setState(() => _error = _message(error));
    } finally {
      if (_active(operation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(HistoricalDesign item) async {
    if (_busy || !authSession.authenticated) return;

    final operation = ++_operation;

    setState(() {
      _busy = true;
      _selected = null;
      _error = null;
    });

    try {
      final selected =
          item.approved
              ? await _repository.approvedRevision(widget.projectId, item.id)
              : item;

      if (!_active(operation)) return;

      if (selected.blueprint == null) {
        setState(() {
          _error = uiText(
            context,
            'This draft version has no saved Blueprint.',
            'இந்தப் பதிப்பில் சேமிக்கப்பட்ட Blueprint இல்லை.',
          );
        });

        return;
      }

      setState(() => _selected = selected);
    } catch (error) {
      if (!_active(operation)) return;

      setState(() => _error = _message(error));
    } finally {
      if (_active(operation)) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final enabled = authSession.authenticated && !_busy && !isLocalDemo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              uiText(context, 'Design History', 'வடிவமைப்பு வரலாறு'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              uiText(
                context,
                'Inspect historical designs without changing the current draft.',
                'தற்போதைய வரைவை மாற்றாமல் பழைய வடிவமைப்புகளைப் பாருங்கள்.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('load-approved-history'),
                  onPressed: enabled ? () => _load(true) : null,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(
                    uiText(
                      context,
                      'Approved revisions',
                      'அங்கீகரிக்கப்பட்ட பதிப்புகள்',
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('load-draft-history'),
                  onPressed: enabled ? () => _load(false) : null,
                  icon: const Icon(Icons.history),
                  label: Text(
                    uiText(context, 'Draft versions', 'வரைவு பதிப்புகள்'),
                  ),
                ),
              ],
            ),
            if (isLocalDemo)
              Text(
                uiText(
                  context,
                  'Server history is unavailable in local demo mode.',
                  'உள்ளூர் மாதிரியில் சேவையக வரலாறு கிடைக்காது.',
                ),
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_loaded) ...[
              const SizedBox(height: 16),
              Text(
                _approved
                    ? uiText(
                      context,
                      'Approved revision history',
                      'அங்கீகரிக்கப்பட்ட பதிப்பு வரலாறு',
                    )
                    : uiText(
                      context,
                      'Draft version history',
                      'வரைவு பதிப்பு வரலாறு',
                    ),
              ),
              if (_records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    uiText(
                      context,
                      'No historical records found.',
                      'வரலாற்றுப் பதிவுகள் இல்லை.',
                    ),
                  ),
                ),
            ],
            for (final item in _records)
              Card(
                child: ListTile(
                  title: Text(
                    '${item.approved ? "Approved" : "Draft"} v${item.version}',
                  ),
                  subtitle: Text(item.timestamp.toLocal().toString()),
                  trailing: OutlinedButton(
                    key: ValueKey('preview-history-${item.id}'),
                    onPressed:
                        enabled && item.blueprint != null
                            ? () => _open(item)
                            : null,
                    child: Text(uiText(context, 'Preview', 'முன்னோட்டம்')),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            if (selected != null && selected.blueprint != null) ...[
              const Divider(height: 32),
              Text(
                'Historical preview — v${selected.version}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                uiText(
                  context,
                  'Read-only simulation. Changes are not saved.',
                  'வாசிப்பு மட்டும். மாற்றங்கள் சேமிக்கப்படாது.',
                ),
              ),
              const SizedBox(height: 12),
              SafePreview(
                key: ValueKey('${widget.projectId}-${selected.id}'),
                blueprint: selected.blueprint!,
              ),
              TextButton(
                onPressed: () => setState(() => _selected = null),
                child: Text(
                  uiText(context, 'Close preview', 'முன்னோட்டத்தை மூடு'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
