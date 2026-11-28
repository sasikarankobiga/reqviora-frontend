import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../l10n/language_settings.dart';
import '../../domain/mcp_access_grant.dart';

class McpGrantsContent extends StatelessWidget {
  const McpGrantsContent({
    super.key,
    required this.revisions,
    required this.grants,
    required this.lifetimes,
    required this.revisionId,
    required this.lifetime,
    required this.credential,
    required this.error,
    required this.busy,
    required this.onRevision,
    required this.onLifetime,
    required this.onCreate,
    required this.onDismissCredential,
    required this.onRevoke,
  });

  final List<McpApprovedRevision> revisions;
  final List<McpAccessGrant> grants;
  final List<Duration> lifetimes;
  final String? revisionId;
  final Duration lifetime;
  final String? credential;
  final String? error;
  final bool busy;
  final ValueChanged<String?> onRevision;
  final ValueChanged<Duration?> onLifetime;
  final VoidCallback onCreate;
  final VoidCallback onDismissCredential;
  final ValueChanged<McpAccessGrant> onRevoke;

  String _status(
    BuildContext context,
    McpGrantStatus status,
  ) => switch (status) {
    McpGrantStatus.active => uiText(context, 'Active', 'செயலில் உள்ளது'),
    McpGrantStatus.expired => uiText(context, 'Expired', 'காலாவதியானது'),
    McpGrantStatus.revoked => uiText(context, 'Revoked', 'ரத்து செய்யப்பட்டது'),
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        uiText(
          context,
          'Scope: fixed read-only MCP V1 access',
          'வரம்பு: நிலையான வாசிப்பு மட்டும் MCP V1 அணுகல்',
        ),
      ),
      Text(
        '${apiBaseUrl.replaceAll(RegExp(r'/+$'), '')}/api/mcp/v1/tools/call',
      ),
      const Text('Header: X-MCP-Grant'),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (revisions.isEmpty && !busy && error == null)
        Text(
          uiText(
            context,
            'Approve a project revision before creating a grant.',
            'அனுமதியை உருவாக்கும் முன் திட்ட பதிப்பை அங்கீகரிக்கவும்.',
          ),
        ),
      if (revisions.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          initialValue: revisionId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: uiText(
              context,
              'Approved revision',
              'அங்கீகரிக்கப்பட்ட பதிப்பு',
            ),
          ),
          items: [
            for (final item in revisions)
              DropdownMenuItem(
                value: item.revisionId,
                child: Text(
                  'v${item.draftVersion} · ${item.revisionId}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: busy ? null : onRevision,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<Duration>(
          initialValue: lifetime,
          decoration: InputDecoration(
            labelText: uiText(context, 'Expiry', 'காலாவதி'),
          ),
          items: [
            for (final item in lifetimes)
              DropdownMenuItem(
                value: item,
                child: Text(
                  '${item.inMinutes} '
                  '${uiText(context, 'minutes', 'நிமிடங்கள்')}',
                ),
              ),
          ],
          onChanged: busy ? null : onLifetime,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: busy || credential != null ? null : onCreate,
          icon: const Icon(Icons.key),
          label: Text(uiText(context, 'Create grant', 'அனுமதியை உருவாக்கு')),
        ),
      ],
      if (credential != null)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uiText(
                    context,
                    'One-time credential—save it now.',
                    'ஒருமுறை சான்று—இப்போது பாதுகாப்பாக சேமிக்கவும்.',
                  ),
                ),
                SelectableText(
                  credential!,
                  key: const ValueKey('mcp-live-credential'),
                ),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed:
                          () => Clipboard.setData(
                            ClipboardData(text: credential!),
                          ),
                      icon: const Icon(Icons.copy),
                      label: Text(uiText(context, 'Copy', 'நகலெடு')),
                    ),
                    TextButton(
                      onPressed: onDismissCredential,
                      child: Text(uiText(context, 'Dismiss', 'மறை')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const Divider(height: 28),
      Text(
        uiText(context, 'Existing grants', 'தற்போதைய அனுமதிகள்'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (grants.isEmpty)
        Text(uiText(context, 'No grants found.', 'அனுமதிகள் இல்லை.')),
      for (final grant in grants)
        ListTile(
          title: Text(grant.id, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${_status(context, grant.statusAt(DateTime.now()))} · '
            '${grant.expiresAt.toLocal()}',
          ),
          trailing:
              grant.canRequestRevocationAt(DateTime.now())
                  ? IconButton(
                    onPressed: busy ? null : () => onRevoke(grant),
                    icon: const Icon(Icons.block),
                    tooltip: uiText(context, 'Revoke', 'ரத்து செய்'),
                  )
                  : null,
        ),
    ],
  );
}
