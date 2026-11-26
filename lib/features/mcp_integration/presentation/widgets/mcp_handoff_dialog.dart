import 'package:reqviora_frontend/l10n/language_settings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../projects/application/projects_providers.dart';
import '../../data/repositories/mcp_repository.dart';

final mcpRepositoryProvider = Provider<McpRepository>((ref) {
  return McpRepository(ref.watch(apiClientProvider));
});

class McpHandoffButton extends ConsumerWidget {
  const McpHandoffButton({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      key: const ValueKey('open-mcp-handoff'),
      icon: const Icon(Icons.integration_instructions_outlined),
      label: const LocalizedUiText('MCP & Developer Handoff'),
      onPressed: () {
        final repository = ref.read(mcpRepositoryProvider);

        showDialog<void>(
          context: context,
          builder:
              (_) => McpHandoffDialog(
                projectId: projectId,
                repository: repository,
              ),
        );
      },
    );
  }
}

class McpHandoffDialog extends StatefulWidget {
  const McpHandoffDialog({
    super.key,
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final McpRepository repository;

  @override
  State<McpHandoffDialog> createState() => _McpHandoffDialogState();
}

class _McpHandoffDialogState extends State<McpHandoffDialog> {
  McpCatalog? catalog;
  bool busy = true;
  String? error;
  String? result;
  String? resultTitle;
  bool copied = false;

  @override
  void initState() {
    super.initState();
    loadCatalog();
  }

  String describeError(Object failure) {
    if (failure is ApiException) {
      return switch (failure.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'You do not have permission to read this project.',
        404 => 'MCP service or requested data is unavailable.',
        0 => 'Cannot reach the MCP service. Check your connection.',
        429 => 'Too many requests. Try again later.',
        _ => 'MCP request failed (HTTP ${failure.statusCode}).',
      };
    }

    if (failure is FormatException &&
        failure.message == 'Unsupported or non-read-only MCP catalog') {
      return 'Unsupported or non-read-only MCP catalog. Access denied.';
    }

    return 'MCP response could not be processed. Refresh the catalog.';
  }

  Future<void> loadCatalog() async {
    setState(() {
      busy = true;
      error = null;
      catalog = null;
      result = null;
      resultTitle = null;
      copied = false;
    });

    try {
      final value = await widget.repository.getCatalog();

      if (mounted) {
        setState(() => catalog = value);
      }
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

  Future<void> runTool(McpTool tool) async {
    if (busy || !(catalog?.tools.contains(tool) ?? false)) {
      return;
    }

    setState(() {
      busy = true;
      error = null;
      result = null;
      resultTitle = null;
      copied = false;
    });

    try {
      final data = await widget.repository.callTool(
        projectId: widget.projectId,
        tool: tool,
      );

      if (!mounted) return;

      setState(() {
        resultTitle = tool.label;
        result =
            data == null
                ? 'No validation result is available.'
                : const JsonEncoder.withIndent('  ').convert(data);
      });
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

  Future<void> loadPrompt(McpPrompt prompt) async {
    if (busy || !(catalog?.prompts.contains(prompt) ?? false)) {
      return;
    }

    setState(() {
      busy = true;
      result = null;
      resultTitle = null;
      error = null;
      copied = false;
    });

    try {
      final text = await widget.repository.getPrompt(prompt);

      if (!mounted) return;

      setState(() {
        resultTitle = prompt.label;
        result = text;
      });
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

  Future<void> copyResult() async {
    final value = result;
    if (value == null || busy) return;

    try {
      await Clipboard.setData(ClipboardData(text: value));

      if (mounted) {
        setState(() => copied = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not copy the result.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = catalog;

    return AlertDialog(
      title: const LocalizedUiText('MCP & Developer Handoff'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Chip(
                avatar: Icon(Icons.lock_outline, size: 18),
                label: LocalizedUiText('Read-only project context'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Inspect server-provided project context for '
                'developer handoff. Current draft data is not '
                'an approved revision.',
              ),
              const SizedBox(height: 12),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: busy ? null : loadCatalog,
                icon: const Icon(Icons.refresh),
                label: const LocalizedUiText('Refresh Catalog'),
              ),
              if (available != null) ...[
                const Divider(height: 28),
                Text(
                  'Available tools',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tool in available.tools)
                      OutlinedButton(
                        key: ValueKey('mcp-tool-${tool.name}'),
                        onPressed: busy ? null : () => runTool(tool),
                        child: Text(tool.label),
                      ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  'Prompt templates',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final prompt in available.prompts)
                      OutlinedButton(
                        onPressed: busy ? null : () => loadPrompt(prompt),
                        child: Text(prompt.label),
                      ),
                  ],
                ),
                const Divider(height: 28),
                Text(
                  'Resource references',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final resource in available.resources)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText(
                      resource.replaceAll('{projectId}', widget.projectId),
                    ),
                  ),
              ],
              if (result != null) ...[
                const Divider(height: 28),
                Text(
                  resultTitle ?? 'Result',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    result!,
                    key: const ValueKey('mcp-result'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const LocalizedUiText(
                  'Only share project data with authorized recipients.',
                ),
                TextButton.icon(
                  onPressed: busy ? null : copyResult,
                  icon: const Icon(Icons.copy),
                  label: Text(copied ? 'Copied' : 'Copy Result'),
                ),
              ],
              const Divider(height: 28),
              const Text(
                'For official Second Brain packages, use the '
                'approved revision export in Builder Step 08.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalizedUiText('Close'),
        ),
      ],
    );
  }
}
