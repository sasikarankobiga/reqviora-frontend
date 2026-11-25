import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/local_preview_blueprint.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';

void main() {
  test('Local preview preserves component properties and hierarchy', () {
    final workspace = Workspace(
      projectId: 'p1',
      draftId: 'd1',
      version: 1,
      projectName: 'Demo',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {
            'id': 's1',
            'name': 'Dashboard',
            'accessRoles': ['Admin'],
          },
        ],
        'components': [
          {
            'id': 'parent',
            'screenId': 's1',
            'type': 'container',
            'label': 'Parent',
            'properties': {'padding': 24},
          },
          {
            'id': 'child',
            'parentComponentId': 'parent',
            'screenId': 's1',
            'type': 'header',
            'label': 'Child',
            'text': 'Welcome',
            'properties': {'alignment': 'right'},
          },
        ],
        'routes': <Map<String, dynamic>>[],
      },
    );

    final result = buildLocalPreviewBlueprint(workspace);
    final screens = result['screens'] as List;
    final components = result['componentInstances'] as List;

    expect(screens.first['accessRoles'], ['Admin']);
    expect(components.first['props']['padding'], 24);
    expect(components.last['parentComponentId'], 'parent');
    expect(components.last['props']['alignment'], 'right');
    expect(components.last['props']['text'], 'Welcome');
  });

  test('Explicit props override legacy properties', () {
    final workspace = Workspace(
      projectId: 'p1',
      draftId: 'd1',
      version: 1,
      projectName: 'Demo',
      designTargets: const ['web'],
      sections: {
        'screens': [
          {'id': 's1', 'name': 'Home'},
        ],
        'components': [
          {
            'id': 'c1',
            'screenId': 's1',
            'type': 'text',
            'properties': {'fontSize': 14, 'alignment': 'left'},
            'props': {'fontSize': 20},
          },
        ],
        'routes': <Map<String, dynamic>>[],
      },
    );

    final result = buildLocalPreviewBlueprint(workspace);
    final components = result['componentInstances'] as List;
    final props = components.single['props'] as Map;

    expect(props['fontSize'], 20);
    expect(props['alignment'], 'left');
  });
}
