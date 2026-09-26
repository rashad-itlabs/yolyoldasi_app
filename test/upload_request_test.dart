import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/error/result.dart';
import 'package:yolyoldasi/core/network/api_client.dart';
import 'package:yolyoldasi/core/network/upload_file.dart';
import 'package:yolyoldasi/core/services/token_storage.dart';
import 'package:yolyoldasi/features/profile/data/services/driver_api_service.dart';
import 'package:yolyoldasi/features/profile/domain/entities/user_enums.dart';

/// Sends a real multipart request through Dio's own transport to a local
/// server, because the stub adapters used elsewhere skip exactly the step that
/// broke: Dio refused to build the request (a null `Content-Type` header
/// clashing with the JSON default) and nothing ever reached the API.
void main() {
  late HttpServer server;
  late String? contentType;
  late String body;

  setUp(() async {
    contentType = null;
    body = '';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final bytes = await request.fold<List<int>>([], (all, chunk) {
        return all..addAll(chunk);
      });
      contentType = request.headers.value(HttpHeaders.contentTypeHeader);
      body = latin1.decode(bytes);
      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'data': {}}));
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  UploadFile jpeg(String name) => UploadFile.fromExtension(
    bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 7)]),
    extension: 'jpg',
    baseName: name,
  );

  test(
    'a two-sided document leaves the phone as one multipart request',
    () async {
      final api = DriverApiService(
        ApiClient(
          tokens: InMemoryTokenStorage(),
          baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        ),
      );

      final result = await api.uploadDocument(
        type: DocumentType.idCard,
        file: jpeg('id_card_front'),
        backFile: jpeg('id_card_back'),
      );

      expect(result, isA<Ok<void>>());
      expect(contentType, startsWith('multipart/form-data; boundary='));
      expect(body, contains('name="type"'));
      expect(body, contains('id_card'));
      expect(body, contains('name="file"; filename="id_card_front.jpg"'));
      expect(body, contains('name="back_file"; filename="id_card_back.jpg"'));
      expect(body, contains('content-type: image/jpeg'));
    },
  );
}
