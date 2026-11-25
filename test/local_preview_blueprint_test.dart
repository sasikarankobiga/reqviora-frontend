import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/domain/local_preview_blueprint.dart';

Workspace makeWorkspace({
  required List<Map<String, dynamic>> screens,
  List<Map<String, dynamic>> components = const [],
  List<Map<String, dynamic>> routes = const [],
}) {
  return Workspace(
    projectId: 'project-test',
    draftId: 'draft-test',
    version: 1,
    projectName: 'Demo',
    designTargets: const ['web'],
    sections: {
      'screens': screens,
      'components': components,
      'routes': routes,
      'theme': {'primaryColor': '#123456'},
    },
  );
}

void main() {
  test('Builds a preview from existing Builder sections', () {
    final workspace = makeWorkspace(
      screens: [
        {'id': 'screen-1', 'name': 'Home'},
        {'id': 'screen-2', 'name': 'Details'},
      ],
      components: [
        {
          'id': 'component-1',
          'screenId': 'screen-1',
          'type': 'button',
          'label': 'Open details',
          'text': '',
        },
      ],
      routes: [
        {
          'id': 'route-1',
          'fromScreenId': 'screen-1',
          'toScreenId': 'screen-2',
          'trigger': 'tap',
        },
      ],
    );

    final result = buildLocalPreviewBlueprint(workspace);

    expect(result['previewOnly'], true);
    expect(result['origin'], 'manual-builder');

    final screens = result['screens'] as List;
    final components = result['componentInstances'] as List;
    final routes = result['routes'] as List;

    expect(screens.length, 2);
    expect(screens.first['screenId'], 'screen-1');
    expect(components.first['type'], 'button');
    expect(components.first['props']['label'], 'Open details');
    expect(routes.first['targetScreenId'], 'screen-2');
    expect(result['designTokens']['primaryColor'], '#123456');
  });

  test('Rejects a preview without screens', () {
    final workspace = makeWorkspace(screens: []);

    expect(() => buildLocalPreviewBlueprint(workspace), throwsStateError);
  });

  test('Rejects routes to missing screens', () {
    final workspace = makeWorkspace(
      screens: [
        {'id': 'screen-1', 'name': 'Home'},
      ],
      routes: [
        {
          'fromScreenId': 'screen-1',
          'toScreenId': 'missing-screen',
          'trigger': 'tap',
        },
      ],
    );

    expect(() => buildLocalPreviewBlueprint(workspace), throwsStateError);
  });
}
