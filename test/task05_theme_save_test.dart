import 'package:flutter_test/flutter_test.dart';
import 'package:reqviora_frontend/features/workspace/domain/theme_draft_tokens.dart';

void main() {
  test('Theme save retains unrelated existing design tokens', () {
    final existing = <String, dynamic>{
      'primaryColor': '#000000',
      'customBrandToken': 'keep-me',
      'typography': {'headingScale': 1.25},
    };

    final saved = buildThemeDraftTokens(
      existing: existing,
      primaryColor: '#112233',
      secondaryColor: '#445566',
      mode: 'dark',
      fontFamily: 'Arial',
      baseSpacing: 12,
      borderRadius: 20,
    );

    expect(saved['primaryColor'], '#112233');
    expect(saved['secondaryColor'], '#445566');
    expect(saved['mode'], 'dark');
    expect(saved['fontFamily'], 'Arial');
    expect(saved['baseSpacing'], 12);
    expect(saved['borderRadius'], 20);
    expect(saved['customBrandToken'], 'keep-me');
    expect(saved['typography'], {'headingScale': 1.25});
    expect(existing['primaryColor'], '#000000');
  });

  test('Theme save works when draft has no previous theme', () {
    final saved = buildThemeDraftTokens(
      existing: <String, dynamic>{},
      primaryColor: '#6654E8',
      secondaryColor: '#2C8FCE',
      mode: 'system',
      fontFamily: 'Roboto',
      baseSpacing: 8,
      borderRadius: 12,
    );

    expect(saved.length, 6);
    expect(saved['mode'], 'system');
    expect(saved['baseSpacing'], 8);
    expect(saved['borderRadius'], 12);
  });
}
