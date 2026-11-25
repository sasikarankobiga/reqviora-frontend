class BuilderQualityChecks {
  const BuilderQualityChecks._();

  static List<String> duplicateNames(List<Map<String, dynamic>> items) {
    final seen = <String, String>{};
    final duplicates = <String>{};

    for (final item in items) {
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;

      final key = name.toLowerCase();

      if (seen.containsKey(key)) {
        duplicates.add(seen[key]!);
      } else {
        seen[key] = name;
      }
    }

    return duplicates.toList();
  }

  static List<String> unreachableFromEntry(
    List<Map<String, dynamic>> screens,
    List<Map<String, dynamic>> routes, {
    String? entryScreenId,
  }) {
    final ids =
        screens
            .map((screen) => (screen['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();

    if (ids.isEmpty) return [];

    final start = entryScreenId ?? ids.first;

    if (!ids.contains(start)) {
      throw ArgumentError.value(entryScreenId, 'entryScreenId');
    }

    final edges = <String, List<String>>{};

    for (final route in routes) {
      final from = (route['fromScreenId'] ?? '').toString();
      final to = (route['toScreenId'] ?? '').toString();

      if (!ids.contains(from) || !ids.contains(to)) continue;

      edges.putIfAbsent(from, () => []).add(to);
    }

    final reached = <String>{start};
    final queue = <String>[start];

    for (var index = 0; index < queue.length; index++) {
      for (final next in edges[queue[index]] ?? <String>[]) {
        if (reached.add(next)) {
          queue.add(next);
        }
      }
    }

    return [
      for (final screen in screens)
        if (!reached.contains((screen['id'] ?? '').toString()))
          (screen['name'] ?? 'Unnamed screen').toString(),
    ];
  }
}
