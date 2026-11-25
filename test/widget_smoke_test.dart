import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reqviora_frontend/app/reqviora_app.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/features/projects/application/projects_providers.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';

void main() {
  testWidgets('dashboard renders without a backend', (tester) async {
    authSession.signIn('widget-test-not-a-real-token');
    addTearDown(() => authSession.signOut());
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectsProvider.overrideWith((ref) async => <ProjectSummary>[]),
        ],
        child: const ReqvioraApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('REQVIORA'), findsOneWidget);
    expect(find.text('Your design workspace'), findsOneWidget);
    expect(find.text('Create project'), findsWidgets);
  });
}
