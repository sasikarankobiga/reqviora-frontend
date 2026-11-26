import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/app/session_provider_scope.dart';
import 'package:reqviora_frontend/core/auth/auth_session.dart';
import 'package:reqviora_frontend/features/projects/domain/project.dart';

void main() {
  setUp(authSession.signOut);
  tearDown(authSession.signOut);

  test('Nested identity is restored from saved draft sections', () {
    final draft = ProjectDraft.fromJson({
      'projectId': 'project-1',
      'version': 3,
      'concurrencyToken': 'token-3',
      'project': {'name': 'Original project', 'primaryPlatform': 'web'},
      'draft': {
        'sections': {
          'identity': {
            'name': 'Updated project',
            'description': 'Updated description',
            'category': 'Education',
            'designTargets': ['web', 'mobile'],
            'tagline': 'Design better',
          },
          'features': [
            {'id': 'FEAT-001'},
          ],
        },
      },
    });

    expect(draft.name, 'Updated project');
    expect(draft.description, 'Updated description');
    expect(draft.category, 'Education');
    expect(draft.targets, ['web', 'mobile']);
    expect(draft.field('tagline'), 'Design better');
    expect(draft.version, 3);
    expect(draft.concurrencyToken, 'token-3');
    expect(draft.rawDraft['sections']['features'], [
      {'id': 'FEAT-001'},
    ]);
  });

  test('Existing root-level drafts remain compatible', () {
    final draft = ProjectDraft.fromJson({
      'projectId': 'project-2',
      'version': 1,
      'project': {'name': 'Original project', 'primaryPlatform': 'web'},
      'draft': {
        'identity': {
          'name': 'Root identity',
          'category': 'Technology',
          'designTargets': ['mobile'],
        },
      },
    });

    expect(draft.name, 'Root identity');
    expect(draft.category, 'Technology');
    expect(draft.targets, ['mobile']);
  });

  test('Nested identity takes precedence over stale root identity', () {
    final draft = ProjectDraft.fromJson({
      'projectId': 'project-3',
      'version': 2,
      'draft': {
        'identity': {'name': 'Old value'},
        'sections': {
          'identity': {'name': 'Current value'},
        },
      },
    });

    expect(draft.name, 'Current value');
  });

  testWidgets('Account change replaces the provider container', (tester) async {
    var creations = 0;
    var disposals = 0;

    final cachedAccountData = Provider<int>((ref) {
      ref.onDispose(() => disposals++);
      return ++creations;
    });

    authSession.signIn('account-one');

    await tester.pumpWidget(
      SessionProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              final value = ref.watch(cachedAccountData);

              return Scaffold(body: Text('Cache $value'));
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cache 1'), findsOneWidget);

    authSession.signOut();

    await tester.pumpAndSettle();

    expect(find.text('Cache 1'), findsNothing);
    expect(find.text('Cache 2'), findsOneWidget);
    expect(disposals, 1);

    authSession.signIn('account-two');

    await tester.pumpAndSettle();

    expect(find.text('Cache 3'), findsOneWidget);
    expect(find.text('Cache 2'), findsNothing);
    expect(disposals, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(disposals, 3);
  });

  testWidgets('Token refresh preserves the current provider cache', (
    tester,
  ) async {
    var creations = 0;

    final cachedData = Provider<int>((ref) => ++creations);

    authSession.startSession(
      accessToken: 'access-one',
      refreshToken: 'refresh-one',
      accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    final generation = authSession.generation;

    await tester.pumpWidget(
      SessionProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              return Scaffold(body: Text('Cache ${ref.watch(cachedData)}'));
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cache 1'), findsOneWidget);

    final refreshed = authSession.replaceRefreshedSession(
      expectedGeneration: generation,
      expectedRefreshToken: 'refresh-one',
      accessToken: 'access-two',
      refreshToken: 'refresh-two',
      accessExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
    expect(authSession.generation, generation);
    expect(find.text('Cache 1'), findsOneWidget);
    expect(creations, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
