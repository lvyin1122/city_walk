import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mambo/core/api/api_client.dart';
import 'package:mambo/core/api/api_exception.dart';

void main() {
  final endpoint = Uri.parse('https://backend.test/graphql');

  ApiClient clientReturning(
    http.Response response, {
    AccessTokenProvider? accessToken,
    void Function(http.Request request)? onRequest,
  }) {
    return ApiClient(
      endpoint: endpoint,
      accessToken: accessToken,
      httpClient: MockClient((request) async {
        onRequest?.call(request);
        return response;
      }),
    );
  }

  http.Response jsonResponse(Object body, {int status = 200}) {
    return http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  group('request', () {
    test('posts the document and variables as JSON to the endpoint', () async {
      late http.Request sent;
      final client = clientReturning(
        jsonResponse({
          'data': {'ok': true},
        }),
        onRequest: (request) => sent = request,
      );

      await client.execute('query Q(\$id: String) { ok }', variables: {'id': '1'});

      expect(sent.method, 'POST');
      expect(sent.url, endpoint);
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'query': 'query Q(\$id: String) { ok }',
        'variables': {'id': '1'},
      });
    });

    test('omits "variables" when there are none', () async {
      late http.Request sent;
      final client = clientReturning(
        jsonResponse({'data': <String, dynamic>{}}),
        onRequest: (request) => sent = request,
      );

      await client.execute('query { ok }');

      expect((jsonDecode(sent.body) as Map).containsKey('variables'), isFalse);
    });

    test('sends the access token as a bearer token', () async {
      late http.Request sent;
      final client = clientReturning(
        jsonResponse({'data': <String, dynamic>{}}),
        accessToken: () => 'token-123',
        onRequest: (request) => sent = request,
      );

      await client.execute('query { ok }');

      expect(sent.headers['Authorization'], 'Bearer token-123');
    });

    test('sends no Authorization header when signed out', () async {
      late http.Request sent;
      final client = clientReturning(
        jsonResponse({'data': <String, dynamic>{}}),
        accessToken: () => null,
        onRequest: (request) => sent = request,
      );

      await client.execute('query { ok }');

      expect(sent.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('response', () {
    test('returns the data object', () async {
      final client = clientReturning(
        jsonResponse({
          'data': {
            'walk': {'Id': 'w1', 'title': '上环漫步'},
          },
        }),
      );

      final data = await client.execute('query { walk { Id title } }');

      expect(data['walk'], {'Id': 'w1', 'title': '上环漫步'});
    });

    test('a 200 response carrying GraphQL errors is a failure', () async {
      final client = clientReturning(
        jsonResponse({
          'data': null,
          'errors': [
            {'message': 'Walk not found'},
          ],
        }),
      );

      await expectLater(
        client.execute('query { walk { Id } }'),
        throwsA(
          isA<ApiGraphQLException>()
              .having((e) => e.messages, 'messages', ['Walk not found'])
              .having((e) => e.details, 'details', 'Walk not found'),
        ),
      );
    });

    test('a non-200 status is a failure that keeps the status code', () async {
      final client = clientReturning(http.Response('upstream down', 502));

      await expectLater(
        client.execute('query { ok }'),
        throwsA(
          isA<ApiHttpException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.details, 'details', 'upstream down'),
        ),
      );
    });

    test('401 tells the user to sign in again', () async {
      final client = clientReturning(http.Response('', 401));

      await expectLater(
        client.execute('query { ok }'),
        throwsA(
          isA<ApiHttpException>().having(
            (e) => e.userMessage,
            'userMessage',
            contains('重新登录'),
          ),
        ),
      );
    });

    test('a body that is not JSON is a format failure', () async {
      final client = clientReturning(http.Response('<html>oops</html>', 200));

      await expectLater(
        client.execute('query { ok }'),
        throwsA(isA<ApiResponseFormatException>()),
      );
    });

    test('a response without data is a format failure', () async {
      final client = clientReturning(jsonResponse({'data': null}));

      await expectLater(
        client.execute('query { ok }'),
        throwsA(isA<ApiResponseFormatException>()),
      );
    });
  });

  group('transport failures', () {
    test('no connection', () async {
      final client = ApiClient(
        endpoint: endpoint,
        httpClient: MockClient(
          (request) async => throw const SocketException('Network is unreachable'),
        ),
      );

      await expectLater(
        client.execute('query { ok }'),
        throwsA(isA<ApiNetworkException>()),
      );
    });

    test('no answer within the timeout', () async {
      final client = ApiClient(
        endpoint: endpoint,
        httpClient: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{"data":{}}', 200);
        }),
      );

      await expectLater(
        client.execute('query { ok }', timeout: const Duration(milliseconds: 20)),
        throwsA(isA<ApiTimeoutException>()),
      );
    });
  });

  test('toString is the user-facing message, never the technical detail', () {
    final exception = ApiGraphQLException(['column "user_id" does not exist']);

    expect('加载失败：$exception', isNot(contains('user_id')));
    expect(exception.toString(), exception.userMessage);
  });
}
