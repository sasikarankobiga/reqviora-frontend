import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reqviora_frontend/core/network/api_client.dart';
import 'package:reqviora_frontend/features/mcp_integration/data/repositories/mcp_repository.dart';

void main() {
  const projectId = '11111111-1111-4111-8111-111111111111';

  McpRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = ApiClient(MockClient(handler));
    addTearDown(client.dispose);
    return McpRepository(client);
  }

  http.Response response(Object? data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> catalog({bool readOnly = true}) => {
    'protocolVersion': 'v1',
    'readOnly': readOnly,
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
  };

  test('Loads catalog and excludes unknown tools', () async {
    final repo = repository((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/mcp/v1/catalog');
      return response(catalog());
    });

    final result = await repo.getCatalog();

    expect(result.tools.length, 3);
    expect(result.prompts.length, 2);
    expect(result.resources.length, 1);
  });

  test('Rejects writable catalogs', () async {
    final repo = repository((request) async {
      return response(catalog(readOnly: false));
    });

    await expectLater(repo.getCatalog(), throwsFormatException);
  });

  test('Rejects unsupported protocol version', () async {
    final repo = repository((request) async {
      return response({...catalog(), 'protocolVersion': 'v2'});
    });

    await expectLater(repo.getCatalog(), throwsFormatException);
  });

  test('Reads project workflow summary', () async {
    final repo = repository((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/mcp/v1/tools/call');
      expect(jsonDecode(request.body), {
        'name': 'reqviora.project.overview',
        'projectId': projectId,
      });

      return response({
        'projectId': projectId,
        'currentDraftVersion': 2,
        'requirements': 5,
        'features': 3,
        'screens': 4,
      });
    });

    final result = await repo.callTool(
      projectId: projectId,
      tool: McpTool.overview,
    );

    expect(result!['requirements'], 5);
  });

  test('Rejects invalid project ID before request', () async {
    final repo = repository((request) async {
      fail('Invalid project ID must not be sent');
    });

    await expectLater(
      repo.callTool(projectId: 'invalid', tool: McpTool.overview),
      throwsArgumentError,
    );
  });

  test('Rejects mismatched project context', () async {
    final repo = repository((request) async {
      return response({
        'projectId': '22222222-2222-4222-8222-222222222222',
        'requirements': 1,
        'features': 1,
        'screens': 1,
      });
    });

    await expectLater(
      repo.callTool(projectId: projectId, tool: McpTool.overview),
      throwsFormatException,
    );
  });

  test('Reads current Blueprint without modifying it', () async {
    final repo = repository((request) async {
      expect(jsonDecode(request.body)['name'], 'reqviora.blueprint.current');

      return response({
        'projectId': projectId,
        'schemaVersion': '1.0.0',
        'screens': [],
      });
    });

    final result = await repo.callTool(
      projectId: projectId,
      tool: McpTool.blueprint,
    );

    expect(result!['schemaVersion'], '1.0.0');
  });

  test('Handles missing latest validation', () async {
    final repo = repository((request) async {
      return http.Response('', 204);
    });

    final result = await repo.callTool(
      projectId: projectId,
      tool: McpTool.validation,
    );

    expect(result, isNull);
  });

  test('Loads validation summary', () async {
    final repo = repository((request) async {
      expect(jsonDecode(request.body)['name'], 'reqviora.validation.latest');

      return response({
        'id': 'validation-id',
        'draftVersionId': 'draft-version-id',
        'passed': true,
        'validatedAt': '2026-11-25T08:00:00Z',
      });
    });

    final result = await repo.callTool(
      projectId: projectId,
      tool: McpTool.validation,
    );

    expect(result!['passed'], isTrue);
  });

  test('Loads requirement review prompt', () async {
    final repo = repository((request) async {
      expect(request.url.path, '/api/mcp/v1/prompts/requirements-review');

      return response({
        'name': 'requirements-review',
        'template': 'Never auto-approve requirements.',
      });
    });

    expect(
      await repo.getPrompt(McpPrompt.requirementsReview),
      'Never auto-approve requirements.',
    );
  });

  test('Rejects mismatched prompt response', () async {
    final repo = repository((request) async {
      return response({'name': 'unexpected', 'template': 'Incorrect template'});
    });

    await expectLater(
      repo.getPrompt(McpPrompt.requirementsReview),
      throwsFormatException,
    );
  });

  test('Preserves server permission denial', () async {
    final repo = repository((request) async {
      return response({'title': 'Forbidden'}, 403);
    });

    await expectLater(
      repo.callTool(projectId: projectId, tool: McpTool.overview),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('Handles disabled MCP service', () async {
    final repo = repository((request) async {
      return http.Response('', 404);
    });

    await expectLater(
      repo.getCatalog(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          404,
        ),
      ),
    );
  });
}
