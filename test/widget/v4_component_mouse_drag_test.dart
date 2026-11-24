import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/workspace.dart';
import 'package:reqviora_frontend/features/workspace/presentation/authoring_page.dart';

void main() {
  testWidgets(
    'actual desktop mouse drag reorders and saves component data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final workspace = Workspace(
        projectId: 'project-1',
        draftId: 'draft-1',
        version: 1,
        projectName: 'Drag Test',
        designTargets: const ['web'],
        sections: {
          'screens': [
            {'id': 'screen-1', 'name': 'Dashboard'},
          ],
          'components': [
            {
              'id': 'component-a',
              'screenId': 'screen-1',
              'type': 'text',
              'label': 'First Component',
              'properties': {'fontSize': 18},
            },
            {
              'id': 'component-b',
              'screenId': 'screen-1',
              'type': 'button',
              'label': 'Second Component',
              'properties': {'enabled': true},
            },
            {
              'id': 'component-c',
              'screenId': 'screen-1',
              'type': 'card',
              'label': 'Third Component',
              'properties': {'elevation': 4},
            },
          ],
        },
      );

      List<Map<String, dynamic>>? saved;
      var saveCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: SingleChildScrollView(
              child: V4ComponentsStudio(
                workspace: workspace,
                onSave: (section, data) async {
                  expect(section, 'components');
                  saveCalls++;
                  saved = (data as List)
                      .map(
                        (item) => Map<String, dynamic>.from(item as Map),
                      )
                      .toList();
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final firstLabel = find.text('First Component');
      final thirdLabel = find.text('Third Component');

      expect(firstLabel, findsOneWidget);
      expect(thirdLabel, findsOneWidget);

      // Desktop drag handles are separate from the item labels.
      // The handle order follows the component list order.
      final handles = find.byType(ReorderableDragStartListener);

      expect(handles, findsNWidgets(3));

      final handle = handles.first;
      final start = tester.getCenter(handle);
      final destinationY = tester.getCenter(thirdLabel).dy + 35;
      final distanceY = destinationY - start.dy;

      await tester.timedDragFrom(
        start,
        Offset(0, distanceY),
        const Duration(milliseconds: 900),
      );

      await tester.pumpAndSettle();

      expect(saveCalls, 1);
      expect(saved, isNotNull);

      expect(
        saved!.map((item) => item['id']).toList(),
        ['component-b', 'component-c', 'component-a'],
      );

      expect(saved![0]['screenId'], 'screen-1');
      expect(saved![1]['screenId'], 'screen-1');
      expect(saved![2]['screenId'], 'screen-1');

      expect(
        (saved![0]['properties'] as Map)['enabled'],
        isTrue,
      );

      expect(
        (saved![1]['properties'] as Map)['elevation'],
        4,
      );

      expect(
        (saved![2]['properties'] as Map)['fontSize'],
        18,
      );

      final visibleOrder = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((item) => (item.title as Text).data)
          .toList();

      expect(
        visibleOrder,
        [
          'Second Component',
          'Third Component',
          'First Component',
        ],
      );
    },
  );
}
