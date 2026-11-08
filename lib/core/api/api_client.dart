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

/// Gets a fresh access token after the server rejected the current one.
/// Returns null when the session cannot be refreshed.
typedef AccessTokenRefresher = Future<String?> Function();

/// Returns the language tag used for generated backend content.
typedef LanguageTagProvider = String Function();

/// The single way the app talks to the GraphQL backend.
///
/// Every request gets the user's access token, a timeout and the same error
/// handling, so individual calls cannot forget any of them.
class ApiClient {
  ApiClient({
    required this.endpoint,
    http.Client? httpClient,
    this.accessToken,
    this.refreshAccessToken,
    this.onAccountDeleted,
    this.languageTag = defaultLanguageTag,
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
    refreshAccessToken: Env.sendAuthHeader ? _refreshSupabaseSession : null,
    onAccountDeleted: _signOutLocally,
    logRequests: kDebugMode,
  );

  static Future<String?> _refreshSupabaseSession() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) return null;
    try {
      final response = await auth.refreshSession().timeout(
        const Duration(seconds: 15),
      );
      return response.session?.accessToken;
    } catch (_) {
      return null;
    }
  }

  static void _signOutLocally() {
    // The server no longer accepts this account; drop its session so the
    // app returns to sign-in instead of sending more requests with it.
    unawaited(
      Supabase.instance.client.auth
          .signOut(scope: SignOutScope.local)
          .catchError((_) {}),
    );
  }

  static String defaultLanguageTag() => 'zh-Hans';

  final LanguageTagProvider languageTag;
  final Uri endpoint;
  final Duration defaultTimeout;

  /// Logs full requests and responses. They contain user ids, coordinates and
  /// photo URLs, so keep this off in release builds.
  final bool logRequests;

  /// Supplies the token for the `Authorization` header. When null, or when
  /// it returns null, requests are sent without the header.
  final AccessTokenProvider? accessToken;

  /// Called once after an HTTP 401 to get a new token; the request is then
  /// sent again. The server rejects a bad token before running anything, so
  /// repeating the request cannot write twice.
  final AccessTokenRefresher? refreshAccessToken;

  /// Called when the server reports that the signed-in account was deleted.
  final void Function()? onAccountDeleted;

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
    final token = accessToken?.call();
    var response = await _post(body, token, timeout);

    final refresh = refreshAccessToken;
    if (response.statusCode == 401 &&
        token != null &&
        token.isNotEmpty &&
        refresh != null) {
      final fresh = await refresh();
      if (fresh != null && fresh.isNotEmpty && fresh != token) {
        response = await _post(body, fresh, timeout);
      }
    }

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
    final authMessage = _messageWithCode(decoded, 'UNAUTHENTICATED');
    if (authMessage != null) {
      // Resolvers report these with HTTP 200. Only a missing session is
      // fixed by signing in again.
      if (authMessage.contains('account has been deleted')) {
        onAccountDeleted?.call();
        throw ApiAccountDeletedException(errors.join('; '));
      }
      if (authMessage == 'Not allowed') {
        throw ApiForbiddenException(errors.join('; '));
      }
      throw ApiHttpException(401, errors.join('; '));
    }
    if (_hasErrorCode(decoded, 'RATE_LIMITED')) {
      throw ApiRateLimitException(errors.join('; '), daily: false);
    }
    if (_hasErrorCode(decoded, 'QUOTA_EXCEEDED')) {
      throw ApiRateLimitException(errors.join('; '), daily: true);
    }
    if (errors.isNotEmpty) throw ApiGraphQLException(errors);

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiResponseFormatException('Response has no "data" object');
    }
    return data;
  }

  Future<http.Response> _post(
    Map<String, dynamic> body,
    String? token,
    Duration? timeout,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-App-Language': languageTag(),
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
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
    return response;
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

  bool _hasErrorCode(Map<String, dynamic>? decoded, String code) =>
      _messageWithCode(decoded, code) != null;

  /// The message of the first error carrying [code], or null when none does.
  String? _messageWithCode(Map<String, dynamic>? decoded, String code) {
    final errors = decoded?['errors'];
    if (errors is! List) return null;
    for (final e in errors) {
      if (e is Map &&
          e['extensions'] is Map &&
          (e['extensions'] as Map)['code'] == code) {
        return e['message']?.toString() ?? '';
      }
    }
    return null;
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
