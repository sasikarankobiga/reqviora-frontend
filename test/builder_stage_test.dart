import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/core/constants/builder_stages.dart';

void main() {
  test('approved builder count and titles', () {
    expect(builderStageNames.length, 8);
    expect(builderStageNames.first, 'Identity & Audience');
    expect(builderStageNames.last, 'Review & Export');
  });
}
