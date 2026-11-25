import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/v4_blueprint_history.dart';

void main() {
  Map<String, dynamic> blueprint(String text) => {
        'screens': [
          {'screenId': 'home', 'name': 'Home'},
        ],
        'componentInstances': [
          {
            'componentInstanceId': 'title-1',
            'type': 'text',
            'props': {'text': text},
          },
        ],
      };

  String textOf(Map<String, dynamic> data) {
    final components = data['componentInstances'] as List;
    final component = components.first as Map;
    final props = component['props'] as Map;
    return props['text'] as String;
  }

  test('records a Blueprint edit', () {
    final history = V4BlueprintHistory(blueprint('Welcome'));

    expect(history.record(blueprint('Hello')), isTrue);
    expect(textOf(history.current), 'Hello');
    expect(history.canUndo, isTrue);
  });

  test('undo restores original Blueprint', () {
    final history = V4BlueprintHistory(blueprint('Welcome'));

    history.record(blueprint('Hello'));

    final restored = history.undo();

    expect(restored, isNotNull);
    expect(textOf(restored!), 'Welcome');
    expect(history.canRedo, isTrue);
  });

  test('redo restores the edited Blueprint', () {
    final history = V4BlueprintHistory(blueprint('Welcome'));

    history.record(blueprint('Hello'));
    history.undo();

    final restored = history.redo();

    expect(restored, isNotNull);
    expect(textOf(restored!), 'Hello');
  });

  test('new edit clears redo history', () {
    final history = V4BlueprintHistory(blueprint('A'));

    history.record(blueprint('B'));
    history.undo();
    history.record(blueprint('C'));

    expect(history.canRedo, isFalse);
    expect(textOf(history.current), 'C');
  });

  test('no-op edits do not create history entries', () {
    final history = V4BlueprintHistory(blueprint('Welcome'));

    expect(history.record(blueprint('Welcome')), isFalse);
    expect(history.canUndo, isFalse);
  });

  test('returned snapshots cannot mutate stored history', () {
    final history = V4BlueprintHistory(blueprint('Original'));

    final snapshot = history.current;
    final components = snapshot['componentInstances'] as List;
    final component = components.first as Map;
    final props = component['props'] as Map;

    props['text'] = 'Changed externally';

    expect(textOf(history.current), 'Original');
  });

  test('reset clears undo and redo', () {
    final history = V4BlueprintHistory(blueprint('A'));

    history.record(blueprint('B'));
    history.undo();
    history.reset(blueprint('Fresh'));

    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(textOf(history.current), 'Fresh');
  });

  test('history respects configured maximum size', () {
    final history = V4BlueprintHistory(
      blueprint('A'),
      maxHistory: 2,
    );

    history.record(blueprint('B'));
    history.record(blueprint('C'));
    history.record(blueprint('D'));

    expect(history.undoCount, 2);

    history.undo();
    history.undo();

    expect(textOf(history.current), 'B');
    expect(history.canUndo, isFalse);
  });
}
