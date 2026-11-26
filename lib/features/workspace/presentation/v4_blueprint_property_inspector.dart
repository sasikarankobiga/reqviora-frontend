 feature/thikal-v4-frontend-development
import 'package:reqviora_frontend/l10n/language_settings.dart';
=======
 develop
import 'package:flutter/material.dart';

/// Draft-only property editor for a selected Blueprint component.
/// Does not persist data or execute generated code.
class V4BlueprintPropertyInspector extends StatelessWidget {
  const V4BlueprintPropertyInspector({
    super.key,
    required this.component,
    required this.onChanged,
  });

  final Map<String, dynamic>? component;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = component;

    if (selected == null) {
 feature/thikal-v4-frontend-development
      return const LocalizedUiText('Select a component to edit its properties');

      return const Text('Select a component to edit its properties');
 develop
    }

    final id =
        (selected['componentInstanceId'] ?? selected['id'] ?? '').toString();

    final type = (selected['type'] ?? '').toString();

    final rawProps = selected['props'] ?? selected['properties'];

 feature/thikal-v4-frontend-development
    final props =
        rawProps is Map
            ? Map<String, dynamic>.from(rawProps)
            : <String, dynamic>{};

    final props = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};
 develop

    final field = (type == 'text' || type == 'header') ? 'text' : 'label';

    final value = (props[field] ?? '').toString();

    void update(String nextValue) {
      final updatedProps = Map<String, dynamic>.from(props);
      updatedProps[field] = nextValue;

      final updated = Map<String, dynamic>.from(selected);

      if (selected.containsKey('props') ||
          !selected.containsKey('properties')) {
        updated['props'] = updatedProps;
      } else {
        updated['properties'] = updatedProps;
      }

      onChanged(updated);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Component Properties',
 feature/thikal-v4-frontend-development
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
 develop
        ),
        const SizedBox(height: 12),
        Text('Component ID: $id'),
        Text('Type: $type'),
        const SizedBox(height: 14),
        TextFormField(
          key: ValueKey('step07-edit-$field-$id'),
          initialValue: value,
          decoration: InputDecoration(
            labelText: field == 'text' ? 'Text' : 'Label',
            border: const OutlineInputBorder(),
          ),
          onChanged: update,
        ),
        const SizedBox(height: 8),
        const Text(
          'Draft editing only · Not saved to backend',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
