import 'package:flutter/material.dart';

/// Read-only selection panel for the Step 07 Visual Editor.
///
/// Selection only. Editing and persistence are separate steps.
class V4BlueprintSelectionPanel extends StatelessWidget {
  const V4BlueprintSelectionPanel({
    super.key,
    required this.blueprint,
    required this.onSelected,
    this.selectedComponentId,
  });

  final Map<String, dynamic> blueprint;
  final String? selectedComponentId;
  final ValueChanged<String> onSelected;

  List<Map<String, dynamic>> items(String section) =>
      (blueprint[section] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  @override
  Widget build(BuildContext context) {
    final screens = items('screens');
    final components = items('componentInstances');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visual Editor · Components',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (screens.isEmpty)
          const Text('Compile a Blueprint to select components'),
        for (final screen in screens) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              (screen['name'] ?? screen['screenId'] ?? 'Screen').toString(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final component in components.where(
            (item) => item['screenId'] == screen['screenId'],
          ))
            Builder(builder: (context) {
              final id =
                  (component['componentInstanceId'] ?? component['id'] ?? '')
                      .toString();
              if (id.isEmpty) return const SizedBox.shrink();

              final properties = component['props'] ?? component['properties'];
              final props = properties is Map
                  ? Map<String, dynamic>.from(properties)
                  : <String, dynamic>{};

              final label =
                  (props['label'] ?? props['text'] ?? component['type'] ?? id)
                      .toString();

              return ListTile(
                key: ValueKey('select-component-$id'),
                title: Text(label),
                subtitle: Text(component['type']?.toString() ?? ''),
                selected: selectedComponentId == id,
                onTap: () => onSelected(id),
              );
            }),
        ],
      ],
    );
  }
}
