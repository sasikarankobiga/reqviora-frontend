import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/backend_blueprint_mapper.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';

  Workspace makeWorkspace({
    bool evidence = true,
    bool confirmed = true,
    bool linked = true,
    bool route = false,
  }) {
    return Workspace(
      projectId: projectId,
      draftId: 'draft-1',
      version: 3,
      projectName: 'REQVIORA',
      designTargets: const ['web'],
      sections: {
        'requirements': [
          {
            'id': 'requirement-1',
            'text': 'Users must search books.',
            'origin': 'user',
            'status': confirmed ? 'confirmed' : 'suggested',
            if (confirmed) ...{
              'confirmedBy': 'human-reviewer',
              'confirmedAt': '2026-11-26T08:00:00Z',
            },
            'evidence':
                evidence
                    ? [
                      {
                        'sourceId': 'source-1',
                        'locator': 'section 1',
                        'quote': 'Users must search books',
                      },
                    ]
                    : [],
          },
        ],
        'features': [
          {
            'id': 'feature-1',
            'name': 'Search Books',
            'requirementIds': linked ? ['requirement-1'] : [],
          },
        ],
        'screens': [
          {
            'id': 'screen-1',
            'name': 'Home',
            'featureIds': ['feature-1'],
          },
        ],
        'components': [
          {
            'id': 'component-1',
            'screenId': 'screen-1',
            'type': 'button',
            'label': 'Search',
          },
        ],
        'routes':
            route
                ? [
                  {
                    'id': 'route-1',
                    'fromScreenId': 'screen-1',
                    'toScreenId': 'screen-1',
                    'componentId': 'component-1',
                  },
                ]
                : <Map<String, dynamic>>[],
      },
    );
  }

  test('Maps real Builder references to Backend Blueprint v1', () {
    final result = buildBackendBlueprintV1(makeWorkspace());

    expect(result['schemaVersion'], '1.0.0');
    expect(result['projectId'], projectId);
    expect(result['revision'], 4);
    expect(result['lifecycle'], 'draft');

    final requirements = result['requirements'] as List;
    final features = result['features'] as List;
    final screens = result['screens'] as List;
    final components = result['components'] as List;

    expect(requirements.single['id'], 'REQ-REQUIREMENT1');
    expect(features.single['requirementIds'], ['REQ-REQUIREMENT1']);
    expect(screens.single['featureIds'], ['FEAT-FEATURE1']);
    expect(screens.single['componentIds'], ['CMP-COMPONENT1']);
    expect(components.single['type'], 'Button');
    expect(requirements.single['confirmedBy'], 'human-reviewer');
    expect((requirements.single['evidence'] as List), isNotEmpty);
  });

  test('Does not invent missing source evidence', () {
    expect(
      () => buildBackendBlueprintV1(makeWorkspace(evidence: false)),
      throwsStateError,
    );
  });

  test('Does not promote suggested requirements', () {
    expect(
      () => buildBackendBlueprintV1(makeWorkspace(confirmed: false)),
      throwsStateError,
    );
  });

  test('Does not invent feature requirement links', () {
    expect(
      () => buildBackendBlueprintV1(makeWorkspace(linked: false)),
      throwsStateError,
    );
  });

  test('Maps explicitly linked navigation action', () {
    final result = buildBackendBlueprintV1(makeWorkspace(route: true));

    final actions = result['actions'] as List;
    final routes = result['navigation'] as List;
    final components = result['components'] as List;

    expect(actions.single['id'], 'ACT-ROUTE1');
    expect(routes.single['actionId'], 'ACT-ROUTE1');
    expect(components.single['actionIds'], ['ACT-ROUTE1']);
  });
}
