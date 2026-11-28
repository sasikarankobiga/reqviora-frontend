import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../../../../l10n/language_settings.dart';
import '../../data/repositories/mcp_grant_repository.dart';
import '../../domain/mcp_access_grant.dart';
import 'mcp_grants_content.dart';

class McpGrantsDialog extends StatefulWidget {
  const McpGrantsDialog({
    super.key,
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final McpGrantRepository repository;

  @override
  State<McpGrantsDialog> createState() => _McpGrantsDialogState();
}

class _McpGrantsDialogState extends State<McpGrantsDialog> {
  static const _lifetimes = [
    Duration(minutes: 30),
    Duration(days: 1),
    Duration(days: 7),
    Duration(days: 30),
  ];

  var _revisions = const <McpApprovedRevision>[];
  var _grants = const <McpAccessGrant>[];
  var _lifetime = _lifetimes.first;
  String? _revisionId;
  String? _credential;
  String? _error;
  bool _busy = true;
  int _operation = 0;
  late int _generation;

  @override
  void initState() {
    super.initState();
    _generation = authSession.generation;
    authSession.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    authSession.removeListener(_sessionChanged);
    _operation++;
    _credential = null;
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted || _generation == authSession.generation) return;
    _generation = authSession.generation;
    setState(() {
      _operation++;
      _credential = null;
      _revisions = const [];
      _grants = const [];
      _busy = false;
      _error = uiText(
        context,
        'Session changed. Close and reopen this dialog.',
        'அமர்வு மாறியது. இந்த உரையாடலை மூடி மீண்டும் திறக்கவும்.',
      );
    });
  }

  String _message(Object failure) {
    if (failure is ApiException) {
      return switch (failure.statusCode) {
        401 => uiText(context, 'Sign in again.', 'மீண்டும் உள்நுழையவும்.'),
        402 => uiText(
          context,
          'An active project entitlement is required.',
          'செயலில் உள்ள திட்ட உரிமை தேவை.',
        ),
        403 => uiText(
          context,
          'Only the project owner can manage MCP grants.',
          'திட்ட உரிமையாளர் மட்டுமே MCP அனுமதிகளை நிர்வகிக்க முடியும்.',
        ),
        404 => uiText(
          context,
          'MCP grants are disabled or unavailable.',
          'MCP அனுமதிகள் முடக்கப்பட்டுள்ளன அல்லது கிடைக்கவில்லை.',
        ),
        409 => uiText(
          context,
          'Grant state changed. Refresh and retry.',
          'அனுமதி நிலை மாறியது. புதுப்பித்து மீண்டும் முயலவும்.',
        ),
        _ => uiText(
          context,
          'MCP request failed.',
          'MCP கோரிக்கை தோல்வியடைந்தது.',
        ),
      };
    }
    return uiText(context, 'MCP response was invalid.', 'MCP பதில் செல்லாது.');
  }

  Future<void> _load() async {
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _credential = null;
      _error = null;
    });
    try {
      final revisions = await widget.repository.approvedRevisions(
        widget.projectId,
      );
      final grants = await widget.repository.list(widget.projectId);
      if (!mounted || operation != _operation) return;
      setState(() {
        _revisions = revisions;
        _grants = grants.items;
        _revisionId =
            revisions.any((item) => item.revisionId == _revisionId)
                ? _revisionId
                : revisions.firstOrNull?.revisionId;
      });
    } catch (failure) {
      if (mounted && operation == _operation) {
        setState(() => _error = _message(failure));
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final revisionId = _revisionId;
    if (_busy || revisionId == null || _credential != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await widget.repository.create(
        projectId: widget.projectId,
        approvedRevisionId: revisionId,
        lifetime: _lifetime,
      );
      final secret = created.credential.take();
      if (secret == null) throw const FormatException('Missing credential');
      if (!mounted) return;
      setState(() {
        _credential = secret;
        _grants = [created.grant, ..._grants];
      });
    } catch (failure) {
      if (mounted) setState(() => _error = _message(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(McpAccessGrant grant) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              uiText(context, 'Revoke MCP grant', 'MCP அனுமதியை ரத்து செய்'),
            ),
            content: TextField(
              controller: controller,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: uiText(context, 'Reason', 'காரணம்'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const LocalizedUiText('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const LocalizedUiText('Confirm'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (reason == null || reason.trim().length < 3 || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.revoke(
        projectId: widget.projectId,
        grantId: grant.id,
        reason: reason,
      );
      if (mounted) await _load();
    } catch (failure) {
      if (mounted) setState(() => _error = _message(failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      uiText(context, 'MCP Developer Handoff', 'MCP உருவாக்குநர் ஒப்படைப்பு'),
    ),
    content: SizedBox(
      width: 680,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            McpGrantsContent(
              revisions: _revisions,
              grants: _grants,
              lifetimes: _lifetimes,
              revisionId: _revisionId,
              lifetime: _lifetime,
              credential: _credential,
              error: _error,
              busy: _busy,
              onRevision: (value) => setState(() => _revisionId = value),
              onLifetime:
                  (value) => setState(() => _lifetime = value ?? _lifetime),
              onCreate: _create,
              onDismissCredential: () => setState(() => _credential = null),
              onRevoke: _revoke,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : _load,
        child: const LocalizedUiText('Refresh'),
      ),
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const LocalizedUiText('Close'),
      ),
    ],
  );
}
