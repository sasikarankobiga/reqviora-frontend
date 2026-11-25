import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/mcp_integration/data/repositories/mcp_repository.dart';
import 'package:reqviora_frontend/features/mcp_integration/presentation/widgets/mcp_handoff_dialog.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';

  late List<http.Request> requests;

  setUp(() {
    requests = [];
  });

  http.Response response(Object? data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<void> open(
    WidgetTester tester, {
    bool disabled = false,
    bool denied = false,
    bool writable = false,
  }) async {
    final api = ApiClient(
      MockClient((request) async {
        requests.add(request);

        if (request.url.path.endsWith('/catalog')) {
          if (disabled) {
            return http.Response('', 404);
          }

          return response({
            'protocolVersion': 'v1',
            'readOnly': !writable,
            'tools': [
              {'name': 'reqviora.project.overview'},
              {'name': 'reqviora.blueprint.current'},
              {'name': 'reqviora.validation.latest'},
              {'name': 'reqviora.project.delete'},
            ],
            'resources': [
              {
                'uriTemplate': 'reqviora://projects/{projectId}/overview',
                'mimeType': 'application/json',
              },
            ],
            'prompts': [
              {'name': 'requirements-review'},
              {'name': 'blueprint-validation'},
            ],
          });
        }

        if (request.url.path.endsWith('/tools/call')) {
          if (denied) {
            return response({'title': 'Forbidden'}, 403);
          }

          final body = jsonDecode(request.body) as Map;

          expect(request.method, 'POST');
          expect(body['projectId'], projectId);

          switch (body['name']) {
            case 'reqviora.project.overview':
              return response({
                'projectId': projectId,
                'currentDraftVersion': 2,
                'requirements': 5,
                'features': 3,
                'screens': 4,
              });

            case 'reqviora.blueprint.current':
              return response({
                'projectId': projectId,
                'schemaVersion': '1.0.0',
                'screens': [],
              });

            case 'reqviora.validation.latest':
              return http.Response('', 204);

            default:
              fail('Unsupported MCP tool was called');
          }
        }

        if (request.url.path.endsWith('/prompts/requirements-review')) {
          return response({
            'name': 'requirements-review',
            'template': 'Never auto-approve requirements.',
          });
        }

        return response({'title': 'Unexpected request'}, 400);
      }),
    );

    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: McpHandoffDialog(
            projectId: projectId,
            repository: McpRepository(api),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Displays read-only MCP catalog', (tester) async {
    await open(tester);

    expect(find.text('Read-only project context'), findsOneWidget);

    expect(find.byKey(const ValueKey('mcp-tool-overview')), findsOneWidget);

    expect(find.byKey(const ValueKey('mcp-tool-blueprint')), findsOneWidget);

    expect(find.byKey(const ValueKey('mcp-tool-validation')), findsOneWidget);

    expect(requests.length, 1);
    expect(requests.single.method, 'GET');
  });

  testWidgets('Excludes unsupported mutating tools', (tester) async {
    await open(tester);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OutlinedButton &&
            widget.key.toString().contains('mcp-tool-'),
      ),
      findsNWidgets(3),
    );

    expect(find.text('reqviora.project.delete'), findsNothing);
  });

  testWidgets('Displays project overview result', (tester) async {
    await open(tester);

    await tap(tester, find.byKey(const ValueKey('mcp-tool-overview')));

    final result = tester.widget<SelectableText>(
      find.byKey(const ValueKey('mcp-result')),
    );

    expect(result.data, contains('"requirements": 5'));
    expect(result.data, contains('"features": 3'));
    expect(result.data, contains('"screens": 4'));

    expect(find.text('Copy Result'), findsOneWidget);
  });

  testWidgets('Displays current Blueprint JSON', (tester) async {
    await open(tester);

    await tap(tester, find.byKey(const ValueKey('mcp-tool-blueprint')));

    final result = tester.widget<SelectableText>(
      find.byKey(const ValueKey('mcp-result')),
    );

    expect(result.data, contains('"schemaVersion": "1.0.0"'));
  });

  testWidgets('Handles missing validation result', (tester) async {
    await open(tester);

    await tap(tester, find.byKey(const ValueKey('mcp-tool-validation')));

    final result = tester.widget<SelectableText>(
      find.byKey(const ValueKey('mcp-result')),
    );

    expect(result.data, 'No validation result is available.');
  });

  testWidgets('Loads requirement review prompt', (tester) async {
    await open(tester);

    await tap(
      tester,
      find.widgetWithText(OutlinedButton, 'Requirements Review'),
    );

    final result = tester.widget<SelectableText>(
      find.byKey(const ValueKey('mcp-result')),
    );

    expect(result.data, 'Never auto-approve requirements.');
  });

  testWidgets('Handles disabled MCP service', (tester) async {
    await open(tester, disabled: true);

    expect(
      find.text('MCP service or requested data is unavailable.'),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('mcp-tool-overview')), findsNothing);
  });

  testWidgets('Handles denied project access', (tester) async {
    await open(tester, denied: true);

    await tap(tester, find.byKey(const ValueKey('mcp-tool-overview')));

    expect(
      find.text('You do not have permission to read this project.'),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('mcp-result')), findsNothing);
  });

  testWidgets('Rejects non-read-only MCP catalog', (tester) async {
    await open(tester, writable: true);

    expect(
      find.textContaining('Unsupported or non-read-only MCP catalog'),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('mcp-tool-overview')), findsNothing);
  });

  testWidgets('Refresh clears previous project result', (tester) async {
    await open(tester);

    await tap(tester, find.byKey(const ValueKey('mcp-tool-overview')));

    expect(find.byKey(const ValueKey('mcp-result')), findsOneWidget);

    await tap(tester, find.text('Refresh Catalog'));

    expect(find.byKey(const ValueKey('mcp-result')), findsNothing);

    expect(
      requests.where((request) => request.url.path.endsWith('/catalog')).length,
      2,
    );
  });
}
