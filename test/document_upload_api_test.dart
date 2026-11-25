import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reqviora_frontend/core/network/api_client.dart';

void main() {
  const projectId = 'd5859ac2-7a39-4f5a-b937-5f1b2b591111';

  final cases = <String, String>{
    'requirements.pdf': 'application/pdf',
    'requirements.docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'requirements.txt': 'text/plain',
  };

  for (final entry in cases.entries) {
    test('Upload ${entry.key} uses correct multipart contract', () async {
      var calls = 0;

      final client = MockClient((request) async {
        calls++;

        expect(request.method, 'POST');
        expect(request.url.path, '/api/projects/$projectId/documents');

        final contentType = request.headers['content-type'] ?? '';
        expect(contentType, contains('multipart/form-data'));

        final body = latin1.decode(request.bodyBytes);

        expect(body, contains('name="file"'));
        expect(body, contains('filename="${entry.key}"'));
        expect(body, contains(entry.value));

        expect(body, isNot(contains('name="expectedVersion"')));

        return http.Response(
          jsonEncode({
            'id': 'document-id',
            'projectId': projectId,
            'fileName': entry.key,
            'mediaType': entry.value,
            'sizeBytes': 3,
            'createdAt': '2026-11-23T10:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(client);

      final result = await api.uploadSource(
        projectId,
        0,
        entry.key,
        Uint8List.fromList([65, 66, 67]),
      );

      expect(result['fileName'], entry.key);
      expect(calls, 1);

      client.close();
    });
  }

  test('Unsupported file extension is rejected', () async {
    var calls = 0;

    final client = MockClient((request) async {
      calls++;
      return http.Response('Unexpected request', 500);
    });

    final api = ApiClient(client);

    await expectLater(
      api.uploadSource(
        projectId,
        0,
        'script.exe',
        Uint8List.fromList([1, 2, 3]),
      ),
      throwsArgumentError,
    );

    expect(calls, 0);

    client.close();
  });
}
