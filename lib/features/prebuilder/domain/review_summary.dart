class ReviewSummary {
  const ReviewSummary({
    required this.suggested,
    required this.accepted,
    required this.rejected,
    required this.deferred,
  });

  final int suggested;
  final int accepted;
  final int rejected;
  final int deferred;

  int get total => suggested + accepted + rejected + deferred;

  static ReviewSummary fromCandidates(List<Map<String, dynamic>> candidates) {
    int count(String status) =>
        candidates.where((item) => item['status'] == status).length;

    return ReviewSummary(
      suggested: count('suggested'),
      accepted: count('accepted'),
      rejected: count('rejected'),
      deferred: count('deferred'),
    );
  }
}
