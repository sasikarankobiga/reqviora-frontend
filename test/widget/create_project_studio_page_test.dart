import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/projects/presentation/pages/create_project_studio_page.dart';
import 'package:reqviora_frontend/features/projects/presentation/widgets/create_project_story_preview.dart';
import 'package:reqviora_frontend/shared/theme/reqviora_theme.dart';

Future<void> pumpStudio(
  WidgetTester tester, {
  CreateProjectSubmitCallback? onSubmit,
  double width = 1440,
  double height = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ReqvioraTheme.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      home: CreateProjectStudioPage(onSubmit: onSubmit),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> openSection(
  WidgetTester tester,
  String key,
) async {
  final section = find.byKey(Key(key));
  final header = find.descendant(
    of: section,
    matching: find.byType(ListTile),
  );

  expect(header, findsOneWidget);
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

Future<void> typeInto(
  WidgetTester tester,
  String key,
  String text,
) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> submitStudio(WidgetTester tester) async {
  final button = find.byKey(const Key('create-submit'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  testWidgets('Initial form has starter fields and Web selected', (
    tester,
  ) async {
    await pumpStudio(tester);

    expect(
      find.byKey(const Key('create-project-studio-page')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('create-name')), findsOneWidget);
    expect(find.byKey(const Key('create-description')), findsOneWidget);

    final web = tester.widget<ChoiceChip>(
      find.byKey(const Key('create-platform-web')),
    );

    expect(web.selected, isTrue);

    expect(
      find.byKey(const Key('create-targetAudience')),
      findsNothing,
    );

    expect(
      find.byKey(const Key('create-technologyPreferences')),
      findsNothing,
    );

    expect(
      find.byKey(const Key('create-story-preview')),
      findsOneWidget,
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('create-submit')),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('Basic and Advanced sections reveal all nine inputs', (
    tester,
  ) async {
    await pumpStudio(tester);

    await openSection(tester, 'create-basic-section');
    await openSection(tester, 'create-advanced-section');

    for (final key in <String>[
      'create-name',
      'create-description',
      'create-targetAudience',
      'create-projectType',
      'create-industry',
      'create-technologyPreferences',
      'create-constraints',
      'create-integrations',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }

    for (final key in <String>[
      'create-platform-web',
      'create-platform-mobile',
      'create-platform-desktop',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }

    await typeInto(
      tester,
      'create-technologyPreferences',
      'Flutter stays here',
    );

    await openSection(tester, 'create-advanced-section');

    final retainedField = find.byKey(
      const Key('create-technologyPreferences'),
      skipOffstage: false,
    );

    expect(retainedField, findsOneWidget);
    expect(retainedField.hitTestable(), findsNothing);

    await openSection(tester, 'create-advanced-section');

    final reopenedField = tester.widget<TextFormField>(
      find.byKey(const Key('create-technologyPreferences')),
    );

    expect(reopenedField.controller!.text, 'Flutter stays here');
  });

  testWidgets('Name required and minimum two characters', (
    tester,
  ) async {
    var calls = 0;

    await pumpStudio(
      tester,
      onSubmit: (value) async {
        calls++;
        return const CreateProjectSubmissionResult.success();
      },
    );

    await submitStudio(tester);

    expect(find.text('Project Name is required.'), findsOneWidget);
    expect(calls, 0);

    await typeInto(tester, 'create-name', 'A');
    await submitStudio(tester);

    expect(
      find.text('Project Name must contain at least 2 characters.'),
      findsOneWidget,
    );
    expect(calls, 0);

    await typeInto(tester, 'create-name', 'Alpha');
    await submitStudio(tester);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(const Key('create-submit-success')), findsOneWidget);
  });

  testWidgets('Every text input exposes the approved maximum length', (
    tester,
  ) async {
    await pumpStudio(tester);

    await openSection(tester, 'create-basic-section');
    await openSection(tester, 'create-advanced-section');

    const limits = <String, int>{
      'create-name': 200,
      'create-description': 4000,
      'create-targetAudience': 500,
      'create-projectType': 120,
      'create-industry': 120,
      'create-technologyPreferences': 2000,
      'create-constraints': 4000,
      'create-integrations': 4000,
    };

    for (final entry in limits.entries) {
      final field = tester.widget<TextFormField>(
        find.byKey(Key(entry.key)),
      );

      expect(field.controller, isNotNull);

      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(entry.key)),
          matching: find.byType(EditableText),
        ),
      );

      final limiters = editable.inputFormatters
              ?.whereType<LengthLimitingTextInputFormatter>()
              .toList() ??
          <LengthLimitingTextInputFormatter>[];

      expect(limiters, hasLength(1), reason: entry.key);
      expect(limiters.single.maxLength, entry.value, reason: entry.key);

      final formatted = limiters.single.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: 'X' * (entry.value + 1)),
      );

      expect(formatted.text.length, entry.value, reason: entry.key);
    }

    final name = tester.widget<TextFormField>(
      find.byKey(const Key('create-name')),
    );

    expect(name.controller, isNotNull);

    await typeInto(tester, 'create-name', 'N' * 201);

    expect(name.controller!.text.length, lessThanOrEqualTo(200));
  });

  testWidgets('Optional values can be empty on submission', (
    tester,
  ) async {
    CreateProjectFormValue? received;

    await pumpStudio(
      tester,
      onSubmit: (value) async {
        received = value;
        return const CreateProjectSubmissionResult.success();
      },
    );

    await typeInto(tester, 'create-name', 'Simple Project');
    await submitStudio(tester);
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.name, 'Simple Project');
    expect(received!.primaryPlatform, 'web');
    expect(received!.description, isEmpty);
    expect(received!.targetAudience, isEmpty);
    expect(received!.projectType, isEmpty);
    expect(received!.industry, isEmpty);
    expect(received!.technologyPreferences, isEmpty);
    expect(received!.constraints, isEmpty);
    expect(received!.integrations, isEmpty);
  });

  testWidgets('All nine values reach typed callback with trimming', (
    tester,
  ) async {
    CreateProjectFormValue? received;

    await pumpStudio(
      tester,
      onSubmit: (value) async {
        received = value;
        return const CreateProjectSubmissionResult.success();
      },
    );

    await typeInto(tester, 'create-name', '  Design Studio  ');
    await typeInto(tester, 'create-description', '  Creative workspace  ');

    await tester.ensureVisible(
      find.byKey(const Key('create-platform-mobile')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-platform-mobile')));
    await tester.pumpAndSettle();

    final mobile = tester.widget<ChoiceChip>(
      find.byKey(const Key('create-platform-mobile')),
    );

    expect(mobile.selected, isTrue);

    await openSection(tester, 'create-basic-section');

    await typeInto(tester, 'create-targetAudience', '  Designers  ');
    await typeInto(tester, 'create-projectType', '  App  ');
    await typeInto(tester, 'create-industry', '  Education  ');

    await openSection(tester, 'create-advanced-section');

    await typeInto(
      tester,
      'create-technologyPreferences',
      '  Flutter  ',
    );

    await typeInto(tester, 'create-constraints', '  Low bandwidth  ');
    await typeInto(tester, 'create-integrations', '  Analytics  ');

    await submitStudio(tester);
    await tester.pumpAndSettle();

    expect(received, isNotNull);
    expect(received!.name, 'Design Studio');
    expect(received!.description, 'Creative workspace');
    expect(received!.primaryPlatform, 'mobile');
    expect(received!.targetAudience, 'Designers');
    expect(received!.projectType, 'App');
    expect(received!.industry, 'Education');
    expect(received!.technologyPreferences, 'Flutter');
    expect(received!.constraints, 'Low bandwidth');
    expect(received!.integrations, 'Analytics');
  });

  testWidgets('Submission stays loading and prevents duplicates', (
    tester,
  ) async {
    final completer = Completer<CreateProjectSubmissionResult>();
    var calls = 0;

    await pumpStudio(
      tester,
      onSubmit: (value) {
        calls++;
        return completer.future;
      },
    );

    await typeInto(tester, 'create-name', 'Loading Project');
    await submitStudio(tester);

    expect(calls, 1);
    expect(find.text('Creating Project...'), findsOneWidget);
    expect(find.byKey(const Key('create-submit-success')), findsNothing);

    final loadingButton = tester.widget<FilledButton>(
      find.byKey(const Key('create-submit')),
    );

    expect(loadingButton.onPressed, isNull);

    completer.complete(
      const CreateProjectSubmissionResult.success(
        message: 'Creation confirmed.',
      ),
    );

    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Creation confirmed.'), findsOneWidget);
    expect(find.byKey(const Key('create-submit-success')), findsOneWidget);
  });

  testWidgets('Failure preserves typed inputs and allows retry', (
    tester,
  ) async {
    var calls = 0;

    await pumpStudio(
      tester,
      onSubmit: (value) async {
        calls++;

        if (calls == 1) {
          return const CreateProjectSubmissionResult.failure(
            message: 'Creation was not confirmed.',
          );
        }

        return const CreateProjectSubmissionResult.success();
      },
    );

    await typeInto(tester, 'create-name', 'Preserved Project');
    await submitStudio(tester);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('Creation was not confirmed.'), findsOneWidget);
    expect(find.byKey(const Key('create-submit-success')), findsNothing);

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('create-name')),
    );

    expect(field.controller!.text, 'Preserved Project');

    await submitStudio(tester);
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(const Key('create-submit-success')), findsOneWidget);
    expect(find.byKey(const Key('create-submit-error')), findsNothing);
  });

  testWidgets('Thrown callback does not show false success', (
    tester,
  ) async {
    await pumpStudio(
      tester,
      onSubmit: (value) async {
        throw StateError('simulated failure');
      },
    );

    await typeInto(tester, 'create-name', 'Retry Project');
    await submitStudio(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-submit-error')), findsOneWidget);
    expect(find.byKey(const Key('create-submit-success')), findsNothing);

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('create-name')),
    );

    expect(field.controller!.text, 'Retry Project');
  });

  for (final size in <Size>[
    const Size(1440, 900),
    const Size(800, 900),
    const Size(390, 844),
  ]) {
    testWidgets('Responsive layout at ${size.width} px', (
      tester,
    ) async {
      await pumpStudio(
        tester,
        width: size.width,
        height: size.height,
      );

      expect(
        find.byKey(const Key('create-project-studio-page')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('create-name')), findsOneWidget);
      expect(find.byKey(const Key('create-story-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Mobile layout with larger text stays usable', (
    tester,
  ) async {
    await pumpStudio(
      tester,
      width: 390,
      height: 844,
      textScale: 1.4,
    );

    expect(find.byKey(const Key('create-name')), findsOneWidget);
    expect(find.byKey(const Key('create-story-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Platform choice switches the illustrated device', (
    tester,
  ) async {
    await pumpStudio(tester);

    expect(find.byKey(const Key('create-device-web')), findsOneWidget);

    final mobile = find.byKey(const Key('create-platform-mobile'));
    await tester.ensureVisible(mobile);
    await tester.pumpAndSettle();
    await tester.tap(mobile);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-device-mobile')), findsOneWidget);
    expect(find.byKey(const Key('create-device-web')), findsNothing);

    final desktop = find.byKey(const Key('create-platform-desktop'));
    await tester.ensureVisible(desktop);
    await tester.pumpAndSettle();
    await tester.tap(desktop);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-device-desktop')), findsOneWidget);
    expect(find.byKey(const Key('create-device-mobile')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Typing updates project name and description in device', (
    tester,
  ) async {
    await pumpStudio(tester);

    await typeInto(tester, 'create-name', 'Aurora Workspace');
    await typeInto(
      tester,
      'create-description',
      'A creative dashboard for teams',
    );

    final webDevice = find.byKey(const Key('create-device-web'));

    expect(
      find.descendant(
        of: webDevice,
        matching: find.text('Aurora Workspace'),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: webDevice,
        matching: find.text('A creative dashboard for teams'),
      ),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('Device selection animates with 220ms transition', (
    tester,
  ) async {
    await pumpStudio(tester);

    final preview = find.byKey(const Key('create-story-preview'));

    final switchers = tester
        .widgetList<AnimatedSwitcher>(
          find.descendant(
            of: preview,
            matching: find.byType(AnimatedSwitcher),
          ),
        )
        .toList();

    expect(
      switchers.any(
        (item) => item.duration == const Duration(milliseconds: 220),
      ),
      isTrue,
    );

    final mobile = find.byKey(const Key('create-platform-mobile'));
    await tester.ensureVisible(mobile);
    await tester.pumpAndSettle();
    await tester.tap(mobile);
    await tester.pump();

    expect(find.byKey(const Key('create-device-web')), findsOneWidget);
    expect(find.byKey(const Key('create-device-mobile')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-device-web')), findsNothing);
    expect(find.byKey(const Key('create-device-mobile')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion removes preview transitions', (
    tester,
  ) async {
    Future<void> showPlatform(String platform) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ReqvioraTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: CreateProjectStoryPreview(
                primaryPlatform: platform,
                projectName: 'Motion Test',
                projectDescription: 'Static when requested',
              ),
            ),
          ),
        ),
      );
    }

    await showPlatform('web');

    final preview = find.byKey(const Key('create-story-preview'));

    final switchers = tester
        .widgetList<AnimatedSwitcher>(
          find.descendant(
            of: preview,
            matching: find.byType(AnimatedSwitcher),
          ),
        )
        .toList();

    expect(switchers, isNotEmpty);
    expect(
      switchers.every((item) => item.duration == Duration.zero),
      isTrue,
    );

    final container = tester.widget<AnimatedContainer>(preview);
    expect(container.duration, Duration.zero);

    await showPlatform('mobile');
    await tester.pump();

    expect(find.byKey(const Key('create-device-mobile')), findsOneWidget);
    expect(find.byKey(const Key('create-device-web')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
