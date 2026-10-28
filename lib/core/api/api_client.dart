import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mambo/app/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_exception.dart';

/// Returns the signed-in user's access token, or null when signed out.
typedef AccessTokenProvider = String? Function();

/// The single way the app talks to the GraphQL backend.
///
/// Every request gets the user's access token, a timeout and the same error
/// handling, so individual calls cannot forget any of them.
class ApiClient {
  ApiClient({
    required this.endpoint,
    http.Client? httpClient,
    this.accessToken,
    this.defaultTimeout = const Duration(seconds: 30),
    this.logRequests = false,
  }) : _http = httpClient ?? http.Client();

  /// Client used by the app, configured from [Env] and the Supabase session.
  static final ApiClient instance = ApiClient(
    endpoint: Uri.parse(Env.graphqlEndpoint),
    accessToken:
        Env.sendAuthHeader
            ? () => Supabase.instance.client.auth.currentSession?.accessToken
            : null,
    logRequests: kDebugMode,
  );

  final Uri endpoint;
  final Duration defaultTimeout;

  /// Logs full requests and responses. They contain user ids, coordinates and
  /// photo URLs, so keep this off in release builds.
  final bool logRequests;

  /// Supplies the token for the `Authorization` header. When null, or when
  /// it returns null, requests are sent without the header.
  final AccessTokenProvider? accessToken;

  final http.Client _http;

  /// Runs a GraphQL operation and returns the `data` object of the response.
  ///
  /// Throws an [ApiException] when the request fails, times out, returns a
  /// non-200 status, reports GraphQL errors or carries no data.
  Future<Map<String, dynamic>> execute(
    String document, {
    Map<String, dynamic>? variables,
    Duration? timeout,
  }) async {
    final body = <String, dynamic>{'query': document, 'variables': ?variables};
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = accessToken?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      response = await _http
          .post(endpoint, headers: headers, body: json.encode(body))
          .timeout(timeout ?? defaultTimeout);
    } on TimeoutException catch (e) {
      throw ApiTimeoutException('No response within ${e.duration}');
    } on SocketException catch (e) {
      throw ApiNetworkException(e.toString());
    } on http.ClientException catch (e) {
      throw ApiNetworkException(e.toString());
    }

    if (logRequests) _log(body, response);

    final decoded = _decode(response);

    if (response.statusCode != 200) {
      final errors = _errorMessages(decoded);
      throw ApiHttpException(
        response.statusCode,
        errors.isNotEmpty ? errors.join('; ') : _snippet(response.body),
      );
    }
    if (decoded == null) {
      throw ApiResponseFormatException(_snippet(response.body));
    }

    final errors = _errorMessages(decoded);
    if (_isUnauthenticated(decoded)) {
      // The backend rejects a missing session per operation (HTTP 200).
      throw ApiHttpException(401, errors.join('; '));
    }
    if (errors.isNotEmpty) throw ApiGraphQLException(errors);

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiResponseFormatException('Response has no "data" object');
    }
    return data;
  }

  Map<String, dynamic>? _decode(http.Response response) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  List<String> _errorMessages(Map<String, dynamic>? decoded) {
    final errors = decoded?['errors'];
    if (errors is! List) return const [];
    return [
      for (final error in errors)
        if (error is Map && error['message'] != null)
          error['message'].toString()
        else
          'GraphQL error',
    ];
  }

  bool _isUnauthenticated(Map<String, dynamic>? decoded) {
    final errors = decoded?['errors'];
    return errors is List &&
        errors.any(
          (e) =>
              e is Map &&
              e['extensions'] is Map &&
              (e['extensions'] as Map)['code'] == 'UNAUTHENTICATED',
        );
  }

  String _snippet(String body) =>
      body.length > 200 ? body.substring(0, 200) : body;

  void _log(Map<String, dynamic> body, http.Response response) {
    developer.log(
      'POST $endpoint -> ${response.statusCode}\n'
      '${const JsonEncoder.withIndent('  ').convert(body)}\n'
      '${response.body}',
      name: 'ApiClient',
    );
  }
}
