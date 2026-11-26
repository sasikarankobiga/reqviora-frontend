import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/blueprint_recovery_store.dart';

void main() {
  const store = BlueprintRecoveryStore();

  test('Unsaved Blueprint can be restored', () {
    const project = 'recovery-save-test';

    final blueprint = <String, dynamic>{
      'screens': [
        {'screenId': 'home', 'name': 'Home'},
      ],
      'componentInstances': [
        {
          'componentInstanceId': 'title',
          'props': {'text': 'Unsaved edit'},
        },
      ],
    };

    store.save(project, 3, blueprint);

    final restored = store.restore(project, 3);

    expect(restored, blueprint);
    store.clear(project);
  });

  test('Recovery does not cross projects', () {
    const first = 'recovery-project-first';
    const second = 'recovery-project-second';

    store.save(first, 1, {'name': 'First'});

    expect(store.restore(first, 1), {'name': 'First'});
    expect(store.restore(second, 1), isNull);

    store.clear(first);
    store.clear(second);
  });

  test('Stale draft version cannot be restored', () {
    const project = 'recovery-stale-version';

    store.save(project, 2, {'name': 'Old draft'});

    expect(store.restore(project, 3), isNull);
    expect(store.restore(project, 2), isNull);

    store.clear(project);
  });

  test('Successful save can clear recovery', () {
    const project = 'recovery-clear-test';

    store.save(project, 1, {'name': 'Temporary'});

    expect(store.restore(project, 1), isNotNull);

    store.clear(project);

    expect(store.restore(project, 1), isNull);
  });
}
