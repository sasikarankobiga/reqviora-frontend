class V4ComponentLayout {
  static const Set<String> parentTypes = {
    'card',
    'container',
    'section',
  };

  static String? validate(
    List<Map<String, dynamic>> components,
  ) {
    final byId = <String, Map<String, dynamic>>{};

    for (final component in components) {
      final id = (component['id'] ?? '').toString();

      if (id.trim().isEmpty) {
        return 'Component ID is required';
      }

      if (byId.containsKey(id)) {
        return 'Duplicate component ID: $id';
      }

      byId[id] = component;
    }

    for (final component in components) {
      final id = component['id'].toString();
      final parentId = (component['parentComponentId'] ?? '').toString().trim();

      if (parentId.isEmpty) continue;

      if (parentId == id) {
        return 'Component cannot be its own parent';
      }

      final parent = byId[parentId];

      if (parent == null) {
        return 'Missing parent component: $parentId';
      }

      if (!parentTypes.contains(parent['type'])) {
        return 'Parent must be a card, container or section';
      }

      if (parent['screenId'] != component['screenId']) {
        return 'Parent and child must belong to the same screen';
      }
    }

    for (final component in components) {
      final visited = <String>{};
      var current = component;

      while (true) {
        final currentId = current['id'].toString();

        if (!visited.add(currentId)) {
          return 'Circular component hierarchy';
        }

        final parentId = (current['parentComponentId'] ?? '').toString().trim();

        if (parentId.isEmpty) break;

        final parent = byId[parentId];

        if (parent == null) break;

        current = parent;
      }
    }

    return null;
  }

  static Map<String, dynamic> cloneForReuse({
    required Map<String, dynamic> source,
    required String newId,
    required String targetScreenId,
  }) {
    if (newId.trim().isEmpty) {
      throw ArgumentError('New component ID is required');
    }

    if (targetScreenId.trim().isEmpty) {
      throw ArgumentError('Target screen is required');
    }

    final sourceId = (source['id'] ?? '').toString();

    if (sourceId.trim().isEmpty || newId == sourceId) {
      throw ArgumentError('Reusable component requires a new ID');
    }

    final clone = Map<String, dynamic>.from(source);

    clone['id'] = newId;
    clone['screenId'] = targetScreenId;
    clone['templateSourceId'] = sourceId;

    // Reused components start without their original parent.
    clone.remove('parentComponentId');

    final properties = source['properties'];

    if (properties is Map) {
      clone['properties'] = Map<String, dynamic>.from(properties);
    }

    return clone;
  }
}
