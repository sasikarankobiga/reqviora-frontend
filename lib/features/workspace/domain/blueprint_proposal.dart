import 'workspace.dart';

class BlueprintProposal {
  const BlueprintProposal({
    required this.confirmedRequirementIds,
    required this.features,
    required this.screens,
    required this.components,
    required this.actions,
    required this.navigation,
  });

  final List<String> confirmedRequirementIds;
  final List<Map<String, dynamic>> features;
  final List<Map<String, dynamic>> screens;
  final List<Map<String, dynamic>> components;
  final List<Map<String, dynamic>> actions;
  final List<Map<String, dynamic>> navigation;

  static const supportedTypes = <String, String>{
    'text': 'Text',
    'button': 'Button',
    'input': 'TextInput',
    'card': 'Card',
    'list': 'List',
    'container': 'Container',
    'image': 'Image',
    'dialog': 'Dialog',
  };

  static String contractId(String prefix, String value) {
    final normalized = value.trim().toUpperCase();

    if (!RegExp(r'^[A-Z0-9][A-Z0-9._-]*$').hasMatch(normalized)) {
      throw StateError('Invalid $prefix identifier: $value');
    }

    return normalized.startsWith('$prefix-')
        ? normalized
        : '$prefix-$normalized';
  }

  static String requiredText(Map<String, dynamic> row, String key) {
    final value = row[key]?.toString().trim() ?? '';

    if (value.isEmpty) {
      throw StateError('Missing required field: $key');
    }

    return value;
  }

  static Map<String, String> index(
    List<Map<String, dynamic>> rows,
    String prefix,
  ) {
    final result = <String, String>{};
    final mappedIds = <String>{};

    for (final row in rows) {
      final id = requiredText(row, 'id');
      final mapped = contractId(prefix, id);

      if (result.containsKey(id) || !mappedIds.add(mapped)) {
        throw StateError('Duplicate $prefix identifier: $id');
      }

      result[id] = mapped;
    }

    return result;
  }

  static String reference(
    Map<String, String> known,
    dynamic value,
    String label,
  ) {
    final result = known[value?.toString()];

    if (result == null) {
      throw StateError('Missing $label reference: $value');
    }

    return result;
  }

  factory BlueprintProposal.fromWorkspace({
    required Workspace workspace,
    required Set<String> confirmedRequirementIds,
    required Map<String, List<String>> featureRequirementIds,
    required Map<String, String> routeComponentIds,
  }) {
    if (confirmedRequirementIds.isEmpty ||
        confirmedRequirementIds.length > 200) {
      throw StateError('Select 1 to 200 confirmed requirements.');
    }

    for (final id in confirmedRequirementIds) {
      if (id.length > 100 ||
          !RegExp(r'^REQ-[A-Z0-9][A-Z0-9._-]*$').hasMatch(id)) {
        throw StateError('Invalid requirement identifier: $id');
      }
    }

    final sourceFeatures = workspace.items('features');
    final sourceScreens = workspace.items('screens');
    final sourceComponents = workspace.items('components');
    final sourceRoutes = workspace.items('routes');

    if (sourceFeatures.isEmpty || sourceScreens.isEmpty) {
      throw StateError('Add features and screens in Builder Step 02.');
    }

    final featureIndex = index(sourceFeatures, 'FEAT');
    final screenIndex = index(sourceScreens, 'SCR');
    final componentIndex = index(sourceComponents, 'CMP');
    final routeIndex = index(sourceRoutes, 'NAV');

    final features = <Map<String, dynamic>>[];
    final screens = <Map<String, dynamic>>[];
    final components = <Map<String, dynamic>>[];
    final actions = <Map<String, dynamic>>[];
    final navigation = <Map<String, dynamic>>[];

    final coveredRequirements = <String>{};

    for (final feature in sourceFeatures) {
      final id = requiredText(feature, 'id');
      final name = requiredText(feature, 'name');

      final requirements = featureRequirementIds[id] ?? const <String>[];

      if (requirements.isEmpty) {
        throw StateError('Map confirmed requirements to feature: $name');
      }

      if (requirements.toSet().length != requirements.length ||
          requirements.any((id) => !confirmedRequirementIds.contains(id))) {
        throw StateError('Invalid requirement mapping for $name');
      }

      coveredRequirements.addAll(requirements);

      features.add({
        'id': featureIndex[id],
        'name': name,
        'requirementIds': requirements,
      });
    }

    if (!coveredRequirements.containsAll(confirmedRequirementIds)) {
      throw StateError('Every confirmed requirement needs a feature.');
    }

    for (final screen in sourceScreens) {
      final id = requiredText(screen, 'id');
      final name = requiredText(screen, 'name');

      final linked = screen['featureIds'];

      if (linked is! List || linked.isEmpty) {
        throw StateError('Map features to screen: $name');
      }

      final mapped =
          linked.map((id) => reference(featureIndex, id, 'feature')).toList();

      if (mapped.toSet().length != mapped.length) {
        throw StateError('Duplicate feature mapping for $name');
      }

      screens.add({'id': screenIndex[id], 'name': name, 'featureIds': mapped});
    }

    final owners = <String, String>{};
    final componentTypes = <String, String>{};

    for (final component in sourceComponents) {
      final id = requiredText(component, 'id');
      final type = requiredText(component, 'type');
      final mappedType = supportedTypes[type];

      if (mappedType == null) {
        throw StateError(
          'Component type $type is unsupported by Blueprint v1.',
        );
      }

      final screenId = reference(
        screenIndex,
        component['screenId'],
        'component screen',
      );

      owners[id] = screenId;
      componentTypes[id] = mappedType;

      components.add({
        'id': componentIndex[id],
        'screenId': screenId,
        'type': mappedType,
        'variant': 'default',
      });
    }

    for (final route in sourceRoutes) {
      final id = requiredText(route, 'id');

      final from = reference(
        screenIndex,
        route['fromScreenId'],
        'route source',
      );

      final to = reference(screenIndex, route['toScreenId'], 'route target');

      final componentId = routeComponentIds[id];

      if (componentId == null ||
          owners[componentId] != from ||
          componentTypes[componentId] != 'Button') {
        throw StateError('Map route $id to a button on its source screen.');
      }

      final actionId = contractId('ACT', id);
      final navigationId = routeIndex[id]!;

      actions.add({
        'id': actionId,
        'componentId': componentIndex[componentId],
        'kind': 'navigate',
        'navigationId': navigationId,
      });

      navigation.add({
        'id': navigationId,
        'sourceScreenId': from,
        'targetScreenId': to,
        'actionId': actionId,
      });
    }

    return BlueprintProposal(
      confirmedRequirementIds: confirmedRequirementIds.toList()..sort(),
      features: features,
      screens: screens,
      components: components,
      actions: actions,
      navigation: navigation,
    );
  }
}
