import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../../auth/application/auth_providers.dart';
import '../../data/repositories/second_brain_repository.dart';
import '../../domain/second_brain_package.dart';

class SecondBrainViewerButton extends ConsumerWidget {
  const SecondBrainViewerButton({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const ValueKey('open-second-brain-viewer'),
      icon: const Icon(Icons.menu_book_outlined),
      label: Text(
        uiText(context, 'View Second Brain', 'Second Brain ஆவணங்களைப் பார்க்க'),
      ),
      onPressed:
          isLocalDemo || !authSession.authenticated
              ? null
              : () {
                final repository = SecondBrainRepository(
                  ref.read(authRepositoryProvider).api,
                );

                showDialog<void>(
                  context: context,
                  builder:
                      (_) => SecondBrainViewer(
                        projectId: projectId,
                        repository: repository,
                      ),
                );
              },
    );
  }
}

class SecondBrainViewer extends StatefulWidget {
  const SecondBrainViewer({
    super.key,
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final SecondBrainRepository repository;

  @override
  State<SecondBrainViewer> createState() => _SecondBrainViewerState();
}

class _SecondBrainViewerState extends State<SecondBrainViewer> {
  List<Map<String, dynamic>> _exports = [];

  SecondBrainPackage? _package;

  String _document = 'README.md';
  String? _error;

  bool _busy = false;
  bool _loaded = false;

  int _generation = authSession.generation;
  int _operation = 0;

  bool get _enabled => authSession.authenticated && !isLocalDemo && !_busy;

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _clear() {
    _operation++;
    _exports = [];
    _package = null;
    _document = 'README.md';
    _error = null;
    _busy = false;
    _loaded = false;
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;
    setState(_clear);
  }

  @override
  void didUpdateWidget(covariant SecondBrainViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId ||
        oldWidget.repository != widget.repository) {
      _clear();
    }
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _package = null;
    _exports = [];
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
        'Only authorized project owners can access official exports.',
        'அனுமதிக்கப்பட்ட திட்ட உரிமையாளர்கள் மட்டுமே ஆவணங்களைப் பார்க்க முடியும்.',
      );
    }

    if (error is FormatException) {
      return uiText(
        context,
        'Package integrity or format verification failed.',
        'ஆவணத் தொகுப்பின் சரிபார்ப்பு தோல்வியடைந்தது.',
      );
    }

    return uiText(
      context,
      'Second Brain could not be loaded. Please retry.',
      'Second Brain ஆவணங்களைப் பெற முடியவில்லை.',
    );
  }

  Future<void> _load() async {
    if (!_enabled) return;

    final operation = ++_operation;

    setState(() {
      _busy = true;
      _loaded = false;
      _exports = [];
      _package = null;
      _error = null;
    });

    try {
      final records = await widget.repository.listExports(widget.projectId);

      if (!_active(operation)) return;

      final ids = <String>{};

      for (final record in records) {
        final id = record['exportId'];
        final revision = record['approvedRevisionId'];

        if (id is! String ||
            revision is! String ||
            !SecondBrainPackage.validGuid(id) ||
            !SecondBrainPackage.validGuid(revision) ||
            !ids.add(id.toLowerCase())) {
          throw const FormatException('Invalid export record.');
        }
      }

      setState(() {
        _exports = records;
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

  Future<void> _open(Map<String, dynamic> record) async {
    if (!_enabled) return;

    final operation = ++_operation;

    setState(() {
      _busy = true;
      _package = null;
      _document = 'README.md';
      _error = null;
    });

    try {
      final package = await widget.repository.openPackage(
        projectId: widget.projectId,
        exportId: record['exportId'] as String,
        revisionId: record['approvedRevisionId'] as String,
      );

      if (!_active(operation)) return;

      setState(() => _package = package);
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
    final package = _package;

    return AlertDialog(
      title: Text(
        uiText(context, 'Second Brain Documentation', 'Second Brain ஆவணங்கள்'),
      ),
      content: SizedBox(
        width: 850,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                uiText(
                  context,
                  'Read-only documentation from an approved revision.',
                  'அங்கீகரிக்கப்பட்ட பதிப்பின் வாசிப்பு மட்டும் ஆவணங்கள்.',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('second-brain-load'),
                onPressed: _enabled ? _load : null,
                icon: const Icon(Icons.refresh),
                label: Text(
                  uiText(
                    context,
                    'Load official exports',
                    'அதிகாரப்பூர்வ ஆவணங்களைப் பெறுக',
                  ),
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_loaded && _exports.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    uiText(
                      context,
                      'No official exports found. Create an export in Step 08.',
                      'ஆவணத் தொகுப்புகள் இல்லை. படி 08 இல் உருவாக்கவும்.',
                    ),
                  ),
                ),
              for (final record in _exports)
                Card(
                  child: ListTile(
                    title: Text('Revision: ${record['approvedRevisionId']}'),
                    subtitle: Text('${record['createdAt'] ?? ''}'),
                    trailing: OutlinedButton(
                      key: ValueKey("second-brain-open-${record['exportId']}"),
                      onPressed: _enabled ? () => _open(record) : null,
                      child: Text(uiText(context, 'Open', 'திறக்க')),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
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
              if (package != null) ...[
                const Divider(height: 32),
                Chip(
                  avatar: const Icon(Icons.verified_outlined),
                  label: Text(
                    uiText(
                      context,
                      'Package integrity verified',
                      'ஆவணத் தொகுப்பு சரிபார்க்கப்பட்டது',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText('Approved revision: ${package.revisionId}'),
                Text('${package.documents.length} documents'),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  key: const ValueKey('second-brain-document'),
                  isExpanded: true,
                  value: _document,
                  items: [
                    for (final name in package.documents.keys)
                      DropdownMenuItem(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged:
                      !_enabled
                          ? null
                          : (value) {
                            if (value == null) return;

                            setState(() => _document = value);
                          },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    package.documents[_document] ?? '',
                    key: const ValueKey('second-brain-content'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  uiText(
                    context,
                    'Share documentation only with authorized recipients.',
                    'அனுமதிக்கப்பட்டவர்களுடன் மட்டுமே ஆவணங்களைப் பகிரவும்.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(uiText(context, 'Close', 'மூடு')),
        ),
      ],
    );
  }
}
