import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/language_settings.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/mcp_grant_repository.dart';
import 'mcp_grants_dialog.dart';

final mcpGrantRepositoryProvider = Provider(
  (ref) => McpGrantRepository(ref.watch(apiClientProvider)),
);

class McpGrantsButton extends ConsumerWidget {
  const McpGrantsButton({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const ValueKey('open-mcp-grants'),
    icon: const Icon(Icons.key_outlined),
    label: Text(uiText(context, 'MCP Access Grants', 'MCP அணுகல் அனுமதிகள்')),
    onPressed:
        () => showDialog<void>(
          context: context,
          builder:
              (_) => McpGrantsDialog(
                projectId: projectId,
                repository: ref.read(mcpGrantRepositoryProvider),
              ),
        ),
  );
}
