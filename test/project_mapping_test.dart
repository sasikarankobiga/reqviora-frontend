import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';

void main() {
  test('create project metadata maps to prefilled draft', () {
    final draft = ProjectDraft.fromJson({
      'projectId': 'example',
      'draftVersion': 3,
      'project': {
        'name': 'Coffee Shop',
        'description': 'Bookings',
        'category': 'Food & Beverage',
        'designTargets': ['mobile'],
        'identity': {'tagline': 'Your coffee companion'},
      },
    });
    expect(draft.name, 'Coffee Shop');
    expect(draft.version, 3);
    expect(draft.targets, ['mobile']);
    expect(draft.field('tagline'), 'Your coffee companion');
  });
}
