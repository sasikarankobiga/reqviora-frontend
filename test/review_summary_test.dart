import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/prebuilder/domain/review_summary.dart';

void main() {
  test('Empty candidates return zero counts', () {
    final summary = ReviewSummary.fromCandidates([]);
    expect(summary.total, 0);
  });

  test('Suggested candidates are counted', () {
    final summary = ReviewSummary.fromCandidates([
      {'status': 'suggested'},
      {'status': 'suggested'},
    ]);

    expect(summary.suggested, 2);
  });

  test('Review decisions are counted separately', () {
    final summary = ReviewSummary.fromCandidates([
      {'status': 'accepted'},
      {'status': 'rejected'},
      {'status': 'deferred'},
    ]);

    expect(summary.accepted, 1);
    expect(summary.rejected, 1);
    expect(summary.deferred, 1);
  });

  test('Unknown statuses are not counted as accepted', () {
    final summary = ReviewSummary.fromCandidates([
      {'status': 'unknown'},
      {'status': 'accepted'},
    ]);

    expect(summary.accepted, 1);
    expect(summary.total, 1);
  });
}
