import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/workspace/domain/blueprint_proposal.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';

void main() {
  Workspace workspace({String type = 'button'}) => Workspace(
    projectId: 'project-1',
    draftId: 'draft-1',
    version: 1,
    projectName: 'Example',
    designTargets: ['web'],
    sections: {
      'features': [
        {'id': 'f1', 'name': 'Browse menu'},
      ],
      'screens': [
        {
          'id': 's1',
          'name': 'Home',
          'featureIds': ['f1'],
        },
        {
          'id': 's2',
          'name': 'Menu',
          'featureIds': ['f1'],
        },
      ],
      'components': [
        {'id': 'c1', 'screenId': 's1', 'type': type},
      ],
      'routes': [
        {'id': 'r1', 'fromScreenId': 's1', 'toScreenId': 's2'},
      ],
    },
  );

  BlueprintProposal build({
    Set<String> confirmed = const {'REQ-001'},
    Map<String, List<String>> requirements = const {
      'f1': ['REQ-001'],
    },
    Map<String, String> routeComponents = const {'r1': 'c1'},
    String type = 'button',
  }) => BlueprintProposal.fromWorkspace(
    workspace: workspace(type: type),
    confirmedRequirementIds: confirmed,
    featureRequirementIds: requirements,
    routeComponentIds: routeComponents,
  );

  test('Maps local identifiers to Blueprint identifiers', () {
    final proposal = build();

    expect(proposal.features.single['id'], 'FEAT-F1');
    expect(proposal.screens.first['id'], 'SCR-S1');
    expect(proposal.components.single['id'], 'CMP-C1');
    expect(proposal.components.single['type'], 'Button');
  });

  test('Maintains feature to requirement traceability', () {
    final proposal = build();

    expect(proposal.features.single['requirementIds'], ['REQ-001']);
    expect(proposal.screens.first['featureIds'], ['FEAT-F1']);
  });

  test('Maintains navigation and action references', () {
    final proposal = build();

    expect(proposal.actions.single['id'], 'ACT-R1');
    expect(proposal.actions.single['componentId'], 'CMP-C1');
    expect(proposal.actions.single['navigationId'], 'NAV-R1');
    expect(proposal.navigation.single['actionId'], 'ACT-R1');
    expect(proposal.navigation.single['targetScreenId'], 'SCR-S2');
  });

  test('Rejects missing confirmed requirements', () {
    expect(() => build(confirmed: {}), throwsStateError);
  });

  test('Rejects unconfirmed feature mapping', () {
    expect(
      () => build(
        requirements: {
          'f1': ['REQ-002'],
        },
      ),
      throwsStateError,
    );
  });

  test('Rejects missing feature requirement mapping', () {
    expect(() => build(requirements: {}), throwsStateError);
  });

  test('Rejects uncovered confirmed requirements', () {
    expect(() => build(confirmed: {'REQ-001', 'REQ-002'}), throwsStateError);
  });

  test('Rejects missing route component mapping', () {
    expect(() => build(routeComponents: {}), throwsStateError);
  });

  test('Rejects unsupported Blueprint components', () {
    expect(() => build(type: 'chart'), throwsStateError);
  });

  test('Rejects invalid identifiers', () {
    expect(
      () => BlueprintProposal.contractId('FEAT', 'bad/id'),
      throwsStateError,
    );
  });
}
