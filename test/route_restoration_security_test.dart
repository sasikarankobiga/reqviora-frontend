import 'package:flutter_test/flutter_test.dart';

import 'package:reqviora_frontend/app/reqviora_app.dart';

void main() {
  test('safe local destinations preserve project, step, tab and query', () {
    for (var step = 1; step <= 8; step++) {
      final route =
          '/projects/project-42/builder/$step?tab=details&source=resume';
      expect(safeLocalDestination(route), route);
    }

    expect(
      safeLocalDestination('/projects/project-42/overview?tab=members'),
      '/projects/project-42/overview?tab=members',
    );
    expect(safeLocalDestination('/account'), '/account');
    expect(
      safeLocalDestination('/projects/project-42/billing'),
      '/projects/project-42/billing',
    );
    expect(
      safeLocalDestination('/administration/validation-health'),
      '/administration/validation-health',
    );
  });

  test(
    'external, protocol-relative and recursive auth redirects are rejected',
    () {
      expect(safeLocalDestination('https://evil.example/steal'), isNull);
      expect(safeLocalDestination('//evil.example/steal'), isNull);
      expect(safeLocalDestination('javascript:alert(1)'), isNull);
      expect(safeLocalDestination('/login?from=/account'), isNull);
      expect(safeLocalDestination('/register'), isNull);
    },
  );
}
