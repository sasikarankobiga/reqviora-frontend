/// Frontend-only interaction rule validation.
///
/// This is not yet a confirmed backend Blueprint contract.
class V4InteractionRuleValidator {
  static const states = <String>{
    'default',
    'loading',
    'empty',
    'error',
    'success',
    'disabled',
    'permission-denied',
  };

  static const actions = <String>{
    'navigate',
    'show-message',
    'set-state',
  };

  static const componentTriggers = <String, Set<String>>{
    'button': {'onClick'},
    'input': {'onChange', 'onSubmit'},
    'tabs': {'onChange'},
    'list': {'onSelect'},
  };

  static String? validate({
    required Map<String, dynamic> rule,
    required List<Map<String, dynamic>> components,
    required List<Map<String, dynamic>> screens,
  }) {
    String value(String key) => (rule[key] ?? '').toString().trim();

    final name = value('name');
    final componentId = value('componentId');
    final trigger = value('trigger');
    final action = value('action');

    if (name.isEmpty) return 'Rule name is required';

    if (componentId.isEmpty) {
      return 'Select a source component';
    }

    final matches = components.where(
      (c) => (c['id'] ?? '').toString() == componentId,
    );

    if (matches.isEmpty) {
      return 'Source component does not exist';
    }

    final source = matches.first;
    final componentType = (source['type'] ?? '').toString();

    final validTriggers = componentTriggers[componentType];

    if (validTriggers == null) {
      return 'Component type does not support interaction triggers';
    }

    if (!validTriggers.contains(trigger)) {
      return 'Unsupported trigger for component type';
    }

    if (!actions.contains(action)) {
      return 'Unsupported action';
    }

    if (action == 'navigate') {
      final destination = value('targetScreenId');

      if (destination.isEmpty) {
        return 'Destination screen is required';
      }

      if (!screens.any(
        (s) => (s['id'] ?? '').toString() == destination,
      )) {
        return 'Destination screen does not exist';
      }
    }

    if (action == 'set-state' && !states.contains(value('targetState'))) {
      return 'Select a valid target UI state';
    }

    if (action == 'show-message' && value('message').isEmpty) {
      return 'Message text is required';
    }

    return null;
  }
}
