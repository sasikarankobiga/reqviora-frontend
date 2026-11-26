import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/features/mcp_integration/domain/mcp_access_grant.dart';

const projectId = '11111111-1111-4111-8111-111111111111';
const revisionId = '22222222-2222-4222-8222-222222222222';
const grantId = '33333333-3333-4333-8333-333333333333';
const otherId = '44444444-4444-4444-8444-444444444444';

final now = DateTime.utc(2026, 11, 26, 8);

McpApprovedRevision revision({String project = projectId}) =>
    McpApprovedRevision(
      projectId: project,
      revisionId: revisionId,
      draftVersion: 5,
    );

McpAccessGrant grant({
  String id = grantId,
  String project = projectId,
  DateTime? expiry,
  DateTime? revoked,
}) => McpAccessGrant(
  id: id,
  projectId: project,
  revisionId: revisionId,
  createdAt: now,
  expiresAt: expiry ?? now.add(const Duration(days: 1)),
  revokedAt: revoked,
);

void main() {
  test('Valid grant is bound to an approved revision', () {
    expect(grant().matchesRevision(revision()), isTrue);
  });

  test('Active grant has active status', () {
    expect(grant().statusAt(now), McpGrantStatus.active);
  });

  test('Grant expires exactly at expiry boundary', () {
    final item = grant();

    expect(item.statusAt(item.expiresAt), McpGrantStatus.expired);
  });

  test('Revoked status takes precedence over expiry', () {
    final item = grant(revoked: now.add(const Duration(hours: 1)));

    expect(
      item.statusAt(now.add(const Duration(days: 2))),
      McpGrantStatus.revoked,
    );
  });

  test('Rejects invalid grant identifiers', () {
    expect(() => grant(id: 'invalid'), throwsArgumentError);
  });

  test('Rejects empty GUID identifiers', () {
    expect(
      () => grant(id: '00000000-0000-0000-0000-000000000000'),
      throwsArgumentError,
    );
  });

  test('Rejects expiry before creation', () {
    expect(
      () => grant(expiry: now.subtract(const Duration(seconds: 1))),
      throwsArgumentError,
    );
  });

  test('Rejects revocation before creation', () {
    expect(
      () => grant(revoked: now.subtract(const Duration(seconds: 1))),
      throwsArgumentError,
    );
  });

  test('Rejects invalid approved revision version', () {
    expect(
      () => McpApprovedRevision(
        projectId: projectId,
        revisionId: revisionId,
        draftVersion: 0,
      ),
      throwsArgumentError,
    );
  });

  test('Cross-project grant does not match revision', () {
    expect(grant(project: otherId).matchesRevision(revision()), isFalse);
  });

  test('Creation intent requires explicit confirmation', () {
    expect(
      () => McpGrantCreationIntent(
        projectId: projectId,
        revision: revision(),
        expiresAt: now.add(const Duration(days: 1)),
        now: now,
        confirmed: false,
      ),
      throwsArgumentError,
    );
  });

  test('Creation rejects another project revision', () {
    expect(
      () => McpGrantCreationIntent(
        projectId: projectId,
        revision: revision(project: otherId),
        expiresAt: now.add(const Duration(days: 1)),
        now: now,
        confirmed: true,
      ),
      throwsArgumentError,
    );
  });

  test('Creation rejects expired expiry selection', () {
    expect(
      () => McpGrantCreationIntent(
        projectId: projectId,
        revision: revision(),
        expiresAt: now,
        now: now,
        confirmed: true,
      ),
      throwsArgumentError,
    );
  });

  test('Confirmed valid grant intent is accepted', () {
    final intent = McpGrantCreationIntent(
      projectId: projectId,
      revision: revision(),
      expiresAt: now.add(const Duration(days: 1)),
      now: now,
      confirmed: true,
    );

    expect(intent.projectId, projectId);
    expect(intent.revision.revisionId, revisionId);
  });

  test('Expired and revoked grants are not revocable in UI', () {
    expect(
      grant().canRequestRevocationAt(now.add(const Duration(days: 2))),
      isFalse,
    );

    expect(grant(revoked: now).canRequestRevocationAt(now), isFalse);

    expect(grant().canRequestRevocationAt(now), isTrue);
  });

  test('Credential can only be taken once', () {
    final credential = McpGrantCredential('test-credential');

    expect(credential.available, isTrue);
    expect(credential.take(), 'test-credential');
    expect(credential.available, isFalse);
    expect(credential.take(), isNull);
  });

  test('Credential string representation is redacted', () {
    final credential = McpGrantCredential('test-credential');

    expect(credential.toString(), isNot(contains('test-credential')));
  });

  test('Cleared credential cannot be recovered from container', () {
    final credential = McpGrantCredential('test-credential');

    credential.clear();

    expect(credential.available, isFalse);
    expect(credential.take(), isNull);
  });

  test('Invalid credentials are rejected', () {
    for (final value in ['', ' ', 'invalid credential']) {
      expect(() => McpGrantCredential(value), throwsArgumentError);
    }
  });
}
