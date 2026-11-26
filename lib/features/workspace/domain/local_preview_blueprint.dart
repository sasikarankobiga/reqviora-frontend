import 'workspace.dart';

/// Converts manually saved Builder sections to a simulated UI preview.
/// This is not an approved or backend-validated Blueprint.
Map<String, dynamic> buildLocalPreviewBlueprint(Workspace workspace) {
  final sourceScreens = workspace.items('screens');
  final sourceComponents = workspace.items('components');
  final sourceRoutes = workspace.items('routes');

  if (sourceScreens.isEmpty) {
    throw StateError('Add at least one screen in Builder Step 02.');
  }

  final screenIds = <String>{};

  final screens = <Map<String, dynamic>>[];

  for (final screen in sourceScreens) {
    final id = (screen['id'] ?? '').toString().trim();
    final name = (screen['name'] ?? '').toString().trim();

    if (id.isEmpty || name.isEmpty) {
      throw StateError('Every screen needs an ID and a name.');
    }

    if (!screenIds.add(id)) {
      throw StateError('Duplicate screen ID: $id');
    }

    screens.add({
      'screenId': id,
      'name': name,
      if (screen['accessRoles'] is List)
        'accessRoles': List<String>.from(screen['accessRoles'] as List),
    });
  }

  const supportedTypes = {
    'text',
    'header',
    'button',
    'input',
    'card',
    'section',
    'container',
    'list',
    'tabs',
    'table',
    'chart',
    'dialog',
    'image',
  };

  final instances = <Map<String, dynamic>>[];
  final componentIds = <String>{};

  for (var i = 0; i < sourceComponents.length; i++) {
    final component = sourceComponents[i];
    final id = (component['id'] ?? '').toString().trim();
    final screenId = (component['screenId'] ?? '').toString().trim();
    final type = (component['type'] ?? '').toString().trim();

    if (id.isEmpty || !componentIds.add(id)) {
      throw StateError('Component IDs must be present and unique.');
    }

    if (!screenIds.contains(screenId)) {
      throw StateError('Component $id references a missing screen.');
    }

    if (!supportedTypes.contains(type)) {
      throw StateError('Unsupported preview component: $type');
    }

    final props = <String, dynamic>{
      ...Map<String, dynamic>.from(component['properties'] as Map? ?? {}),
      ...Map<String, dynamic>.from(component['props'] as Map? ?? {}),
    };

    props['label'] = component['label'] ?? props['label'] ?? '';
    props['text'] = component['text'] ?? props['text'] ?? '';

    instances.add({
      'componentInstanceId': id,
      if (component['parentComponentId'] != null)
        'parentComponentId': component['parentComponentId'],
      'screenId': screenId,
      'type': type,
      'order': i,
      'props': props,
    });
  }

  final routes = <Map<String, dynamic>>[];

  for (final route in sourceRoutes) {
    final from = (route['fromScreenId'] ?? '').toString().trim();
    final to = (route['toScreenId'] ?? '').toString().trim();

    if (!screenIds.contains(from) || !screenIds.contains(to)) {
      throw StateError('A navigation route references a missing screen.');
    }

    routes.add({
      'sourceScreenId': from,
      'targetScreenId': to,
      'trigger': route['trigger'] ?? 'tap',
      'enabled': true,
    });
  }

  return {
    'previewOnly': true,
    'origin': 'manual-builder',
    'generator': 'local-preview-v1',
    'screens': screens,
    'componentInstances': instances,
    'routes': routes,
    'designTokens': workspace.fields('theme'),
  };
}
