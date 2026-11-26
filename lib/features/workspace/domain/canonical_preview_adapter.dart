/// Display-only adapter for canonical Blueprint v1.
/// Does not modify persisted data or perform network requests.
Map<String, dynamic> adaptCanonicalPreview(Map<String, dynamic> blueprint) {
  if (blueprint['componentInstances'] is List ||
      blueprint['components'] is! List) {
    return blueprint;
  }

  List<Map<String, dynamic>> rows(String key) {
    final raw = blueprint[key];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .where((row) => row.keys.every((key) => key is String))
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  const types = <String, String>{
    'Text': 'text',
    'Button': 'button',
    'TextInput': 'input',
    'Card': 'card',
    'List': 'list',
    'Container': 'container',
    'Image': 'image',
    'Dialog': 'dialog',
  };

  final screenIds = <String>{};
  final screens = <Map<String, dynamic>>[];

  for (final screen in rows('screens')) {
    final id = screen['id'];

    if (id is! String || id.trim().isEmpty || !screenIds.add(id)) {
      continue;
    }

    screens.add({...screen, 'screenId': id});
  }

  final componentIds = <String>{};
  final components = <Map<String, dynamic>>[];

  for (final item in rows('components')) {
    final id = item['id'];

    if (id is! String ||
        id.trim().isEmpty ||
        !screenIds.contains(item['screenId']) ||
        !componentIds.add(id)) {
      continue;
    }

    final raw = item['properties'] ?? item['props'];

    final properties =
        raw is Map && raw.keys.every((key) => key is String)
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

    components.add({
      ...item,
      'componentInstanceId': id,
      'type': types[item['type']] ?? item['type'],
      'props': properties,
    });
  }

  final routes =
      rows('navigation')
          .where(
            (route) =>
                screenIds.contains(route['sourceScreenId']) &&
                screenIds.contains(route['targetScreenId']) &&
                route['enabled'] != false,
          )
          .toList();

  final interactions = <Map<String, dynamic>>[];

  for (final action in rows('actions')) {
    if (action['kind'] != 'navigate') continue;

    final componentId = action['componentId'];

    final source = components.where(
      (component) =>
          component['componentInstanceId'] == componentId &&
          component['type'] == 'button',
    );

    if (source.isEmpty) continue;

    final matches = routes.where(
      (route) =>
          route['id'] == action['navigationId'] &&
          route['actionId'] == action['id'] &&
          route['sourceScreenId'] == source.first['screenId'],
    );

    if (matches.length != 1) continue;

    interactions.add({
      'componentId': componentId,
      'trigger': 'onClick',
      'action': 'navigate',
      'targetScreenId': matches.single['targetScreenId'],
    });
  }

  return {
    ...blueprint,
    'screens': screens,
    'componentInstances': components,
    'routes': routes,
    'interactions': interactions,
  };
}
