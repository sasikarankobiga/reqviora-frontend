class NavigationDiagnostics {
  const NavigationDiagnostics({
    required this.brokenRoutes,
    required this.duplicateRoutes,
    required this.disconnectedScreenNames,
  });

  final int brokenRoutes;
  final int duplicateRoutes;
  final List<String> disconnectedScreenNames;

  static NavigationDiagnostics inspect(
    List<Map<String, dynamic>> screens,
    List<Map<String, dynamic>> routes,
  ) {
    final screenIds = screens.map((s) => s['id'].toString()).toSet();

    final connected = <String>{};
    final signatures = <String>{};

    var broken = 0;
    var duplicates = 0;

    for (final route in routes) {
      final from = route['fromScreenId']?.toString() ?? '';
      final to = route['toScreenId']?.toString() ?? '';
      final trigger = route['trigger']?.toString() ?? '';

      if (!screenIds.contains(from) || !screenIds.contains(to)) {
        broken++;
        continue;
      }

      connected.add(from);
      connected.add(to);

      final signature = '$from|$to|$trigger';

      if (!signatures.add(signature)) {
        duplicates++;
      }
    }

    final disconnected = <String>[];

    for (final screen in screens) {
      if (!connected.contains(screen['id'].toString())) {
        disconnected.add((screen['name'] ?? 'Unnamed screen').toString());
      }
    }

    return NavigationDiagnostics(
      brokenRoutes: broken,
      duplicateRoutes: duplicates,
      disconnectedScreenNames: disconnected,
    );
  }
}
