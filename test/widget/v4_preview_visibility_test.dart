import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/presentation/simulated_preview.dart';

void main() {
  Map<String, dynamic> blueprint() => {
        'screens': [
          {'screenId': 'screen-1', 'name': 'Test Screen'},
        ],
        'componentInstances': [
          {
            'componentInstanceId': 'public-text',
            'screenId': 'screen-1',
            'type': 'text',
            'props': {'text': 'Public content'},
          },
          {
            'componentInstanceId': 'admin-text',
            'screenId': 'screen-1',
            'type': 'text',
            'props': {
              'text': 'Admin content',
              'visibility': {'mode': 'role', 'role': 'admin'},
            },
          },
          {
            'componentInstanceId': 'success-text',
            'screenId': 'screen-1',
            'type': 'text',
            'props': {
              'text': 'Success content',
              'visibility': {'mode': 'state', 'state': 'success'},
            },
          },
        ],
      };

  Future<void> openPreview(
    WidgetTester tester, {
    String? role,
    String state = 'default',
    Map<String, dynamic>? data,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SafePreview(
              blueprint: data ?? blueprint(),
              simulationRole: role,
              simulationState: state,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('public component remains visible', (tester) async {
    await openPreview(tester);
    expect(find.text('Public content'), findsOneWidget);
  });

  testWidgets('viewer cannot see admin component', (tester) async {
    await openPreview(tester, role: 'viewer');
    expect(find.text('Public content'), findsOneWidget);
    expect(find.text('Admin content'), findsNothing);
  });

  testWidgets('admin sees admin component', (tester) async {
    await openPreview(tester, role: 'admin');
    expect(find.text('Admin content'), findsOneWidget);
  });

  testWidgets('success state controls visibility', (tester) async {
    await openPreview(tester, state: 'success');
    expect(find.text('Success content'), findsOneWidget);
    expect(find.text('Admin content'), findsNothing);
  });

  testWidgets('form value updates conditional component', (tester) async {
    final data = <String, dynamic>{
      'screens': [
        {'screenId': 'screen-1', 'name': 'Form Screen'},
      ],
      'componentInstances': [
        {
          'componentInstanceId': 'accountType',
          'screenId': 'screen-1',
          'type': 'input',
          'props': {'label': 'Account Type'},
        },
        {
          'componentInstanceId': 'company-name',
          'screenId': 'screen-1',
          'type': 'text',
          'props': {
            'text': 'Company Name',
            'visibility': {
              'mode': 'fieldEquals',
              'fieldId': 'accountType',
              'equals': 'business',
            },
          },
        },
      ],
    };

    await openPreview(tester, data: data);

    expect(find.text('Company Name'), findsNothing);

    await tester.enterText(find.byType(TextField), 'business');
    await tester.pumpAndSettle();

    expect(find.text('Company Name'), findsOneWidget);
  });
}
