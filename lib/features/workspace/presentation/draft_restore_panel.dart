import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/language_settings.dart';
import '../data/draft_restore_repository.dart';

/// Enable only after the integrated backend contract,
/// project permissions and workspace refresh are verified.
class DraftRestorePanel extends StatefulWidget {
  const DraftRestorePanel({
    super.key,
    required this.projectId,
    required this.historicalVersion,
    required this.repository,
    required this.onRestored,
    this.integrationEnabled = false,
    this.canWrite = false,
  });

  final String projectId;
  final int historicalVersion;
  final DraftRestoreRepository repository;
  final VoidCallback onRestored;
  final bool integrationEnabled;
  final bool canWrite;

  @override
  State<DraftRestorePanel> createState() => _DraftRestorePanelState();
}

class _DraftRestorePanelState extends State<DraftRestorePanel> {
  bool _busy = false;
  bool _awaitingConfirmation = false;
  String? _error;
  int? _restoredVersion;

  int _generation = authSession.generation;
  int _operation = 0;

  bool get _allowed =>
      widget.integrationEnabled &&
      widget.canWrite &&
      widget.historicalVersion > 0 &&
      authSession.authenticated &&
      !isLocalDemo;

  bool get _enabled => _allowed && !_busy && _restoredVersion == null;

  @override
  void initState() {
    super.initState();
    authSession.addListener(_sessionChanged);
  }

  void _clear() {
    _operation++;
    _busy = false;
    _awaitingConfirmation = false;
    _error = null;
    _restoredVersion = null;
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) {
      return;
    }

    _generation = authSession.generation;
    setState(_clear);
  }

  @override
  void didUpdateWidget(covariant DraftRestorePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId ||
        oldWidget.historicalVersion != widget.historicalVersion ||
        oldWidget.repository != widget.repository ||
        oldWidget.integrationEnabled != widget.integrationEnabled ||
        oldWidget.canWrite != widget.canWrite) {
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
      _allowed &&
      _generation == authSession.generation &&
      operation == _operation;

  String _message(Object failure) {
    if (failure is ApiException) {
      if (failure.statusCode == 403) {
        return uiText(
          context,
          'You do not have permission to restore drafts.',
          'வரைவுகளை மீட்டமைக்க உங்களுக்கு அனுமதி இல்லை.',
        );
      }

      if (failure.statusCode == 409) {
        return uiText(
          context,
          'The draft changed or is locked. Reload before restoring.',
          'வரைவு மாறியுள்ளது அல்லது பூட்டப்பட்டுள்ளது. மீண்டும் ஏற்றவும்.',
        );
      }

      if (failure.statusCode == 404) {
        return uiText(
          context,
          'The draft version or restore service is unavailable.',
          'வரைவு பதிப்பு அல்லது மீட்டமைப்பு சேவை கிடைக்கவில்லை.',
        );
      }
    }

    return uiText(
      context,
      'Restoration could not be confirmed. Reload server state before retrying.',
      'மீட்டமைப்பை உறுதிப்படுத்த முடியவில்லை. மீண்டும் முயற்சிக்கும் முன் சேவையக நிலையை ஏற்றவும்.',
    );
  }

  Future<void> _restore() async {
    if (!_enabled) return;

    final operation = ++_operation;
    final projectId = widget.projectId;
    final historicalVersion = widget.historicalVersion;
    final repository = widget.repository;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final current = await repository.current(projectId);

      if (!_active(operation)) return;

      if (current.approved) {
        setState(() {
          _error = uiText(
            context,
            'Approved drafts cannot be restored.',
            'அங்கீகரிக்கப்பட்ட வரைவுகளை மீட்டமைக்க முடியாது.',
          );
        });

        return;
      }

      if (historicalVersion >= current.version) {
        setState(() {
          _error = uiText(
            context,
            'Select an earlier draft version.',
            'முந்தைய வரைவு பதிப்பைத் தேர்ந்தெடுக்கவும்.',
          );
        });

        return;
      }

      if (!mounted) return;

      setState(() => _awaitingConfirmation = true);

      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: Text(
                uiText(
                  dialogContext,
                  'Confirm draft restoration',
                  'வரைவு மீட்டமைப்பை உறுதிப்படுத்தவும்',
                ),
              ),
              content: Text(
                'Restore draft v$historicalVersion as a new '
                'version after current draft v${current.version}?\n\n'
                'Previous saved versions are preserved. '
                'Unsaved changes may be lost. '
                'The restored draft must be validated again.',
              ),
              actions: [
                TextButton(
                  key: const ValueKey('restore-cancel'),
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(uiText(dialogContext, 'Cancel', 'ரத்து செய்')),
                ),
                FilledButton(
                  key: const ValueKey('restore-confirm'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(uiText(dialogContext, 'Restore', 'மீட்டமை')),
                ),
              ],
            ),
      );

      if (!_active(operation) || accepted != true) return;

      setState(() => _awaitingConfirmation = false);

      final result = await repository.restore(
        current: current,
        historicalVersion: historicalVersion,
        confirmed: true,
      );

      if (!_active(operation)) return;

      setState(() {
        _restoredVersion = result.version;
      });

      widget.onRestored();
    } catch (failure) {
      if (!_active(operation)) return;

      setState(() {
        _error = _message(failure);
      });
    } finally {
      if (_active(operation)) {
        setState(() {
          _busy = false;
          _awaitingConfirmation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('restore-draft-button'),
          onPressed: _enabled ? _restore : null,
          icon: const Icon(Icons.restore),
          label: Text(
            uiText(
              context,
              'Restore draft v${widget.historicalVersion}',
              'வரைவு v${widget.historicalVersion} மீட்டமை',
            ),
          ),
        ),
        if (!widget.integrationEnabled)
          Text(
            uiText(
              context,
              'Draft restoration awaits backend integration.',
              'வரைவு மீட்டமைப்பு சேவையக இணைப்புக்காக காத்திருக்கிறது.',
            ),
          )
        else if (!widget.canWrite)
          Text(
            uiText(
              context,
              'Project write permission is required.',
              'திட்டத்தை மாற்றுவதற்கான அனுமதி தேவை.',
            ),
          ),
        if (_busy && !_awaitingConfirmation) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_restoredVersion != null)
          Semantics(
            liveRegion: true,
            child: Text(
              'Draft restored as v$_restoredVersion. '
              'Reload and validate the workspace.',
            ),
          ),
      ],
    );
  }
}
