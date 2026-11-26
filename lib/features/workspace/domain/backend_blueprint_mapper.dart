import 'workspace.dart';

/// Adapts explicit, reviewed Builder data to Backend Blueprint v1.
///
/// Never invents requirement evidence, human confirmation,
/// requirement-feature relationships, or navigation actions.
Map<String, dynamic> buildBackendBlueprintV1(Workspace workspace) {
  String requiredValue(Object? value, String description) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) {
      throw StateError('$description is required.');
    }
    return text;
  }

  String makeId(String prefix, Object? raw) {
    final source = requiredValue(raw, '$prefix source ID');
    final suffix = source.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (suffix.isEmpty || suffix.length > 60) {
      throw StateError('Invalid $prefix source ID: $source');
    }

    return '$prefix-$suffix';
  }

  Map<String, String> ids(List<Map<String, dynamic>> records, String prefix) {
    final result = <String, String>{};
    final used = <String>{};

    for (final record in records) {
      final original = requiredValue(record['id'], '$prefix ID');
      final converted = makeId(prefix, original);

      if (result.containsKey(original) || !used.add(converted)) {
        throw StateError('Duplicate $prefix ID: $original');
      }

      result[original] = converted;
    }

    return result;
  }

  String ref(Map<String, String> lookup, Object? original, String description) {
    final key = requiredValue(original, description);
    final found = lookup[key];

    if (found == null) {
      throw StateError('Broken $description reference: $key');
    }

    return found;
  }

  List<String> refs(
    Map<String, String> lookup,
    Object? values,
    String description, {
    bool required = false,
  }) {
    if (values is! List) {
      throw StateError('$description reference list is required.');
    }

    if (required && values.isEmpty) {
      throw StateError('$description requires at least one reference.');
    }

    final mapped =
        values.map((value) => ref(lookup, value, description)).toList();

    if (mapped.toSet().length != mapped.length) {
      throw StateError('Duplicate $description references.');
    }

    return mapped;
  }

  final requirements = workspace.items('requirements');
  final features = workspace.items('features');
  final screens = workspace.items('screens');
  final components = workspace.items('components');
  final routes = workspace.items('routes');

  if (requirements.isEmpty) {
    throw StateError(
      'Backend Blueprint requires reviewed requirements with source evidence.',
    );
  }

  if (features.isEmpty || screens.isEmpty) {
    throw StateError(
      'Add requirements-linked features and feature-linked screens first.',
    );
  }

  final requirementIds = ids(requirements, 'REQ');
  final featureIds = ids(features, 'FEAT');
  final screenIds = ids(screens, 'SCR');
  final componentIds = ids(components, 'CMP');
  final routeIds = ids(routes, 'NAV');

  final allowedOrigins = {'user', 'document', 'voice', 'ai'};
  final confirmedIds = <String>{};

  final backendRequirements =
      requirements.map((r) {
        final originalId = requiredValue(r['id'], 'Requirement ID');
        final origin = requiredValue(r['origin'], 'Requirement origin');
        final status = requiredValue(r['status'], 'Requirement status');

        if (!allowedOrigins.contains(origin) ||
            !{'suggested', 'confirmed', 'rejected'}.contains(status)) {
          throw StateError('Invalid requirement origin/status: $originalId');
        }

        final evidence = r['evidence'];

        if (evidence is! List || evidence.isEmpty) {
          throw StateError(
            'Requirement $originalId needs real source evidence.',
          );
        }

        final mappedEvidence =
            evidence.map((item) {
              if (item is! Map) {
                throw StateError('Invalid evidence for $originalId');
              }

              return <String, dynamic>{
                'sourceId': requiredValue(
                  item['sourceId'],
                  'Evidence sourceId',
                ),
                'locator': requiredValue(item['locator'], 'Evidence locator'),
                if (item['quote'] != null)
                  'quote': requiredValue(item['quote'], 'Evidence quote'),
              };
            }).toList();

        if (status == 'confirmed') {
          requiredValue(r['confirmedBy'], 'Human confirmation identity');
          requiredValue(r['confirmedAt'], 'Human confirmation timestamp');
          confirmedIds.add(originalId);
        } else if (r['confirmedBy'] != null || r['confirmedAt'] != null) {
          throw StateError(
            'Unconfirmed requirement $originalId has confirmation fields.',
          );
        }

        return <String, dynamic>{
          'id': requirementIds[originalId],
          'text': requiredValue(
            r['text'] ?? r['description'],
            'Requirement text',
          ),
          'origin': origin,
          'status': status,
          if (status == 'confirmed') ...{
            'confirmedBy': r['confirmedBy'],
            'confirmedAt': r['confirmedAt'],
          },
          'evidence': mappedEvidence,
        };
      }).toList();

  final backendFeatures =
      features.map((feature) {
        final original = requiredValue(feature['id'], 'Feature ID');
        final sourceLinks = feature['requirementIds'];

        if (sourceLinks is! List || sourceLinks.isEmpty) {
          throw StateError(
            'Feature $original needs explicit requirement mappings.',
          );
        }

        for (final requirementId in sourceLinks) {
          if (!confirmedIds.contains(requirementId.toString())) {
            throw StateError(
              'Feature $original references an unconfirmed requirement.',
            );
          }
        }

        return <String, dynamic>{
          'id': featureIds[original],
          'name': requiredValue(feature['name'], 'Feature name'),
          'requirementIds': refs(
            requirementIds,
            sourceLinks,
            'Feature requirement',
            required: true,
          ),
        };
      }).toList();

  const supportedTypes = {
    'button': 'Button',
    'input': 'TextInput',
    'text': 'Text',
    'card': 'Card',
    'list': 'List',
    'container': 'Container',
    'image': 'Image',
    'dialog': 'Dialog',
  };

  final backendComponents =
      components.map((component) {
        final original = requiredValue(component['id'], 'Component ID');
        final type = requiredValue(component['type'], 'Component type');
        final mappedType = supportedTypes[type];

        if (mappedType == null) {
          throw StateError(
            'Component $original type $type is not supported by Backend v1.',
          );
        }

        final screen = ref(
          screenIds,
          component['screenId'],
          'Component screen',
        );

        final childIds =
            components
                .where((child) => child['parentComponentId'] == original)
                .map((child) => componentIds[child['id'].toString()]!)
                .toList();

        final props = <String, dynamic>{
          ...Map<String, dynamic>.from(component['properties'] as Map? ?? {}),
          ...Map<String, dynamic>.from(component['props'] as Map? ?? {}),
          if (component['label'] != null) 'label': component['label'],
          if (component['text'] != null) 'text': component['text'],
        };

        return <String, dynamic>{
          'id': componentIds[original],
          'screenId': screen,
          'type': mappedType,
          'props': props,
          'actionIds': [
            for (final route in routes)
              if (route['componentId'] == original) makeId('ACT', route['id']),
          ],
          'childComponentIds': childIds,
        };
      }).toList();

  final backendScreens =
      screens.map((screen) {
        final original = requiredValue(screen['id'], 'Screen ID');

        return <String, dynamic>{
          'id': screenIds[original],
          'name': requiredValue(screen['name'], 'Screen name'),
          'featureIds': refs(
            featureIds,
            screen['featureIds'],
            'Screen feature',
            required: true,
          ),
          'componentIds': [
            for (final component in components)
              if (component['screenId'] == original)
                componentIds[component['id'].toString()]!,
          ],
        };
      }).toList();

  final backendActions = <Map<String, dynamic>>[];
  final backendNavigation = <Map<String, dynamic>>[];

  for (final route in routes) {
    final original = requiredValue(route['id'], 'Route ID');

    // The Builder route UI may not yet specify an action component.
    // Refuse to invent one.
    final sourceComponentId = requiredValue(
      route['componentId'],
      'Navigation $original action componentId',
    );

    final component = components.firstWhere(
      (c) => c['id'] == sourceComponentId,
      orElse: () => <String, dynamic>{},
    );

    if (component.isEmpty) {
      throw StateError('Navigation action component does not exist.');
    }

    final from = requiredValue(
      route['fromScreenId'],
      'Navigation source screen',
    );

    if (component['screenId'] != from) {
      throw StateError('Navigation action must belong to the source screen.');
    }

    final actionId = makeId('ACT', original);
    final navigationId = routeIds[original]!;

    backendActions.add({
      'id': actionId,
      'componentId': ref(
        componentIds,
        sourceComponentId,
        'Navigation component',
      ),
      'kind': 'navigate',
      'navigationId': navigationId,
    });

    backendNavigation.add({
      'id': navigationId,
      'sourceScreenId': ref(screenIds, from, 'Navigation source'),
      'targetScreenId': ref(
        screenIds,
        route['toScreenId'],
        'Navigation destination',
      ),
      'actionId': actionId,
    });
  }

  final targets = workspace.designTargets.toSet().toList();

  if (targets.isEmpty ||
      targets.any((t) => !{'web', 'mobile', 'desktop'}.contains(t))) {
    throw StateError('Unsupported or missing target platform.');
  }

  return <String, dynamic>{
    'schemaVersion': '1.0.0',
    'blueprintId': makeId('BP', workspace.projectId),
    'projectId': workspace.projectId,
    'revision': workspace.version + 1,
    'lifecycle': 'draft',
    'targetPlatforms': targets,
    'requirements': backendRequirements,
    'features': backendFeatures,
    'screens': backendScreens,
    'components': backendComponents,
    'actions': backendActions,
    'navigation': backendNavigation,
  };
}
