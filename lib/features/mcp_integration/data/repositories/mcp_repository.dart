import '../../../../core/network/api_client.dart';

enum McpTool {
  overview('reqviora.project.overview', 'Project Overview'),
  blueprint('reqviora.blueprint.current', 'Current Blueprint'),
  validation('reqviora.validation.latest', 'Latest Validation');

  const McpTool(this.apiName, this.label);

  final String apiName;
  final String label;
}

enum McpPrompt {
  requirementsReview('requirements-review', 'Requirements Review'),
  blueprintValidation('blueprint-validation', 'Blueprint Validation');

  const McpPrompt(this.apiName, this.label);

  final String apiName;
  final String label;
}

class McpCatalog {
  const McpCatalog({
    required this.tools,
    required this.prompts,
    required this.resources,
  });

  final List<McpTool> tools;
  final List<McpPrompt> prompts;
  final List<String> resources;

  factory McpCatalog.fromJson(Map<String, dynamic> json) {
    if (json['protocolVersion'] != 'v1' || json['readOnly'] != true) {
      throw const FormatException('Unsupported or non-read-only MCP catalog');
    }

    final rawTools = json['tools'];
    final rawPrompts = json['prompts'];
    final rawResources = json['resources'];

    if (rawTools is! List || rawPrompts is! List || rawResources is! List) {
      throw const FormatException('Invalid MCP catalog');
    }

    final toolNames =
        rawTools.whereType<Map>().map((item) => item['name']).toSet();

    final promptNames =
        rawPrompts.whereType<Map>().map((item) => item['name']).toSet();

    final resources =
        rawResources
            .whereType<Map>()
            .where((item) => item['mimeType'] == 'application/json')
            .map((item) => item['uriTemplate'])
            .whereType<String>()
            .where(
              (uri) => const [
                'reqviora://projects/{projectId}/overview',
                'reqviora://projects/{projectId}/blueprint/current',
              ].contains(uri),
            )
            .toSet()
            .toList();

    return McpCatalog(
      tools: List.unmodifiable(
        McpTool.values.where((tool) => toolNames.contains(tool.apiName)),
      ),
      prompts: List.unmodifiable(
        McpPrompt.values.where(
          (prompt) => promptNames.contains(prompt.apiName),
        ),
      ),
      resources: List.unmodifiable(resources),
    );
  }
}

class McpRepository {
  const McpRepository(this.api);

  final ApiClient api;

  static const basePath = '/api/mcp/v1';

  Map<String, dynamic> _object(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Invalid MCP response');
    }

    return Map<String, dynamic>.from(value);
  }

  bool _validId(String id) =>
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id) &&
      id != '00000000-0000-0000-0000-000000000000';

  Future<McpCatalog> getCatalog() async {
    return McpCatalog.fromJson(_object(await api.get('$basePath/catalog')));
  }

  Future<Map<String, dynamic>?> callTool({
    required String projectId,
    required McpTool tool,
  }) async {
    if (!_validId(projectId)) {
      throw ArgumentError('Invalid project ID');
    }

    final result = await api.post('$basePath/tools/call', {
      'name': tool.apiName,
      'projectId': projectId,
    });

    if (result == null && tool == McpTool.validation) {
      return null;
    }

    final data = _object(result);

    switch (tool) {
      case McpTool.overview:
        final returnedId = data['projectId'];

        if (returnedId is! String ||
            returnedId.toLowerCase() != projectId.toLowerCase()) {
          throw const FormatException('Unexpected MCP project');
        }

        for (final field in ['requirements', 'features', 'screens']) {
          final count = data[field];

          if (count is! int || count < 0) {
            throw const FormatException('Invalid project workflow count');
          }
        }

      case McpTool.blueprint:
        final returnedId = data['projectId'];

        if (returnedId is! String ||
            returnedId.toLowerCase() != projectId.toLowerCase()) {
          throw const FormatException('Unexpected Blueprint project');
        }

      case McpTool.validation:
        if (data['id'] is! String ||
            data['draftVersionId'] is! String ||
            data['passed'] is! bool) {
          throw const FormatException('Invalid validation summary');
        }
    }

    return data;
  }

  Future<String> getPrompt(McpPrompt prompt) async {
    final result = _object(
      await api.get('$basePath/prompts/${prompt.apiName}'),
    );

    final template = result['template'];

    if (result['name'] != prompt.apiName ||
        template is! String ||
        template.trim().isEmpty) {
      throw const FormatException('Invalid MCP prompt');
    }

    return template;
  }
}
