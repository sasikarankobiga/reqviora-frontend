import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/domain/models/project_draft.dart';

void main() {
  test('Audience details remain in frontend draft', () {
    final draft = ProjectDraft(
      name: 'Student Safety App',
      description: 'A safety management system',
    );

    draft.updateAudience(
      targetAudience: ' Students and Teachers ',
      primaryUserGoal: ' Receive timely safety information ',
    );

    expect(draft.targetAudience, 'Students and Teachers');
    expect(
      draft.primaryUserGoal,
      'Receive timely safety information',
    );
  });

  test('Audience details are excluded from API request', () {
    final draft = ProjectDraft(
      name: 'Student Safety App',
      description: 'A safety management system',
    );

    draft.updateAudience(
      targetAudience: 'Students',
      primaryUserGoal: 'Stay informed',
    );

    final json = draft.toCreateRequest().toJson();

    expect(json['name'], 'Student Safety App');
    expect(json['description'], 'A safety management system');
    expect(json.containsKey('targetAudience'), isFalse);
    expect(json.containsKey('primaryUserGoal'), isFalse);
  });

  test('Audience input length is validated', () {
    final draft = ProjectDraft(
      name: 'Test Project',
      description: '',
    );

    expect(
      () => draft.updateAudience(
        targetAudience: 'A' * 201,
        primaryUserGoal: '',
      ),
      throwsArgumentError,
    );

    expect(
      () => draft.updateAudience(
        targetAudience: '',
        primaryUserGoal: 'B' * 1001,
      ),
      throwsArgumentError,
    );
  });
}
