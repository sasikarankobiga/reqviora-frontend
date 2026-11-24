import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:reqviora_frontend/features/projects/presentation/create_project_page.dart';

void main() {
  Future<void> openCreateProject(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final router = GoRouter(
      initialLocation: '/projects/new',
      routes: [
        GoRoute(
          path: '/projects/new',
          builder: (_, _) => const CreateProjectPage(),
        ),
        GoRoute(
          path: '/projects',
          builder: (_, _) => const Scaffold(body: Text('Projects')),
        ),
      ],
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('Project Name Next focuses Description', (tester) async {
    await openCreateProject(tester);

    final nameField = find.byKey(const ValueKey('create-project-name'));

    final descriptionField = find.byKey(
      const ValueKey('create-project-description'),
    );

    await tester.enterText(nameField, 'Coffee Shop');

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();

    final editableDescription = find.descendant(
      of: descriptionField,
      matching: find.byType(EditableText),
    );

    expect(
      tester.widget<EditableText>(editableDescription).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('Empty project name shows validation error', (tester) async {
    await openCreateProject(tester);

    final submit = find.byKey(const ValueKey('create-project-submit'));

    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Enter a project name'), findsOneWidget);
  });
}
