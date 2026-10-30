import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/services/cloudinary_service.dart';
import 'package:mambo/services/graphql_operations.dart';
import 'package:mambo/services/graphql_service.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/api_exception.dart';

const UploadSignature uploadSignature = (
  cloudName: 'signed-cloud',
  apiKey: 'public-api-key',
  timestamp: 123456789,
  signature: 'short-lived-signature',
  folder: 'mambo/u/user-folder',
  uploadPreset: 'signed-preset',
);

Future<UploadSignature> signatureSource() async => uploadSignature;

class _TrackingClient extends http.BaseClient {
  _TrackingClient(this.reply);

  final http.StreamedResponse Function(http.BaseRequest request) reply;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (closed) throw StateError('Client is closed');
    await request.finalize().drain<void>();
    return reply(request);
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cloudinary_service_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> imageFile() {
    return File('${tempDir.path}/photo.jpg').writeAsBytes([1, 2, 3, 4]);
  }

  test('returns the secure_url from a 200 response', () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"secure_url": "https://example.com/a.jpg"}',
        200,
      ),
    );

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
      signatureSource: signatureSource,
    );

    expect(url, 'https://example.com/a.jpg');
  });

  test('returns null from a 400 response', () async {
    final client = MockClient(
      (_) async => http.Response('{"error":"rejected"}', 400),
    );

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
      signatureSource: signatureSource,
    );

    expect(url, isNull);
  });

  test('returns null when the client never responds', () async {
    final client = MockClient((_) => Completer<http.Response>().future);

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
      signatureSource: signatureSource,
      timeout: const Duration(milliseconds: 100),
    ).timeout(const Duration(seconds: 2));

    expect(url, isNull);
  });

  test('a stalled response body times out and leaves the supplied client usable', () async {
    final body = StreamController<List<int>>();
    var headersReturned = false;
    final client = _TrackingClient((request) {
      if (request.url.path == '/still-open') {
        return http.StreamedResponse(Stream.value(utf8.encode('available')), 200);
      }
      headersReturned = true;
      return http.StreamedResponse(body.stream, 200);
    });
    addTearDown(client.close);
    addTearDown(body.close);
    body.add(utf8.encode('{"secure_url":'));

    final url = await CloudinaryService.uploadImage(
      await imageFile(),
      client: client,
      signatureSource: signatureSource,
      timeout: const Duration(milliseconds: 100),
    ).timeout(const Duration(seconds: 2));

    expect(headersReturned, isTrue);
    expect(url, isNull);
    expect(client.closed, isFalse);
    final response = await client.get(Uri.https('example.test', '/still-open'));
    expect(response.body, 'available');
  });

  for (final statusCode in [200, 400]) {
    test('an HTTP $statusCode upload leaves the supplied client usable', () async {
      final client = _TrackingClient((request) {
        if (request.url.path == '/still-open') {
          return http.StreamedResponse(Stream.value(utf8.encode('available')), 200);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"secure_url":"https://example.com/photo.jpg"}')),
          statusCode,
        );
      });
      addTearDown(client.close);

      final url = await CloudinaryService.uploadImage(
        await imageFile(),
        client: client,
        signatureSource: signatureSource,
      );

      expect(url, statusCode == 200 ? 'https://example.com/photo.jpg' : null);
      expect(client.closed, isFalse);
      final response = await client.get(Uri.https('example.test', '/still-open'));
      expect(response.body, 'available');
    });
  }

  test('posts exactly the signed values and file to the supplied cloud', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response('{"secure_url":"https://example.com/photo.jpg"}', 200);
    });
    await CloudinaryService.uploadImage(await imageFile(), client: client, signatureSource: signatureSource);

    expect(sent.url, Uri.parse('https://api.cloudinary.com/v1_1/signed-cloud/image/upload'));
    expect(sent.method, 'POST');
    final names = RegExp(r'content-disposition: form-data; name="([^"]+)"')
        .allMatches(sent.body).map((match) => match.group(1));
    expect(names, unorderedEquals(['api_key', 'timestamp', 'signature', 'folder', 'upload_preset', 'file']));
    for (final field in {
      'api_key': 'public-api-key', 'timestamp': '123456789',
      'signature': 'short-lived-signature', 'folder': 'mambo/u/user-folder',
      'upload_preset': 'signed-preset',
    }.entries) {
      expect(sent.body, contains('name="${field.key}"\r\n\r\n${field.value}\r\n'));
    }
    expect(sent.bodyBytes, containsAllInOrder([1, 2, 3, 4]));
  });

  test('a failed signature makes no upload request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 200);
    });
    expect(await CloudinaryService.uploadImage(
      await imageFile(), client: client,
      signatureSource: () async => throw const ApiNetworkException('offline'),
    ), isNull);
    expect(calls, 0);
  });

  test('a late signature cannot upload after the shared timeout', () async {
    final signature = Completer<UploadSignature>();
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 200);
    });
    expect(await CloudinaryService.uploadImage(
      await imageFile(), client: client, signatureSource: () => signature.future,
      timeout: const Duration(milliseconds: 20),
    ), isNull);
    signature.complete(uploadSignature);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);
  });

  test('GraphQL signature uses the shared document and parses every signed field', () async {
    late http.Request sent;
    final service = GraphQLService(client: ApiClient(
      endpoint: Uri.parse('https://backend.test/graphql'),
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'data': {'createUploadSignature': {
          'cloudName': uploadSignature.cloudName, 'apiKey': uploadSignature.apiKey,
          'timestamp': uploadSignature.timestamp, 'signature': uploadSignature.signature,
          'folder': uploadSignature.folder, 'uploadPreset': uploadSignature.uploadPreset,
        }}}), 200);
      }),
    ));
    expect(await service.createUploadSignature(), uploadSignature);
    expect((jsonDecode(sent.body) as Map)['query'], GraphQLOperations.createUploadSignature);
  });

  test('GraphQL signature rejects a missing or malformed signed field', () async {
    final complete = <String, Object>{
      'cloudName': 'cloud', 'apiKey': 'api', 'timestamp': 123,
      'signature': 'sig', 'folder': 'folder', 'uploadPreset': 'preset',
    };
    for (final field in complete.keys) {
      final invalid = Map<String, Object>.from(complete)..remove(field);
      final service = GraphQLService(client: ApiClient(
        endpoint: Uri.parse('https://backend.test/graphql'),
        httpClient: MockClient((_) async => http.Response(
          jsonEncode({'data': {'createUploadSignature': invalid}}), 200,
        )),
      ));
      await expectLater(service.createUploadSignature(), throwsA(isA<ApiResponseFormatException>()));
    }
  });

}
